import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:dart_lmdb2/dart_lmdb2.dart';

void main() {
  late LMDB2 db;
  late String dbPath;
  late Directory testDir;

  setUp(() async {
    // Create test directory with unique name
    testDir = Directory(path.join(
      Directory.current.path,
      'test_data',
      'db_${DateTime.now().millisecondsSinceEpoch}',
    ));

    // Ensure clean state
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);

    dbPath = testDir.path;

    // Initialize database
    db = LMDB2();
    try {
      final config = LMDBInitConfig(
        mapSize: LMDBConfig.minMapSize,
      );
      await db.init(dbPath, config: config);
    } catch (e) {
      // If initialization fails, clean up and rethrow
      testDir.deleteSync(recursive: true);
      rethrow;
    }
  });

  tearDown(() async {
    // Ensure database is properly closed
    try {
      db.close();
    } catch (e) {
      print('Warning: Error during database closure: $e');
    } finally {
      // Always try to clean up the test directory
      try {
        if (testDir.existsSync()) {
          testDir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Warning: Error during test directory cleanup: $e');
      }
    }
  });

  test('LMDB2 Version', () {
    final version = db.getVersion();
    expect(version, contains('LMDB'));
  });

  test('Basic put and get operations with auto transactions', () async {
    final key = 'test_key';
    final value = 'test_value';

    await db.putAuto(key, value.codeUnits);
    final result = await db.getAuto(key);

    expect(result, isNotNull);
    expect(String.fromCharCodes(result!), equals(value));
  });

  test('Delete data with auto transaction', () async {
    final key = 'test_key';
    final value = 'test_value';

    await db.putAuto(key, value.codeUnits);
    await db.deleteAuto(key);
    final result = await db.getAuto(key);

    expect(result, isNull);
  });

  test('Non-existent key returns null with auto transaction', () async {
    final result = await db.getAuto('non_existent_key');
    expect(result, isNull);
  });

  test('Multiple operations in single transaction', () async {
    final txn = await db.txnStart();
    try {
      // Put multiple items
      await db.put(txn, 'key1', 'value1'.codeUnits);
      await db.put(txn, 'key2', 'value2'.codeUnits);
      await db.put(txn, 'key3', 'value3'.codeUnits);

      // Verify within same transaction
      var result1 = await db.get(txn, 'key1');
      var result2 = await db.get(txn, 'key2');
      var result3 = await db.get(txn, 'key3');

      expect(String.fromCharCodes(result1!), equals('value1'));
      expect(String.fromCharCodes(result2!), equals('value2'));
      expect(String.fromCharCodes(result3!), equals('value3'));

      // Delete one item
      await db.delete(txn, 'key2');

      // Verify deletion within transaction
      result2 = await db.get(txn, 'key2');
      expect(result2, isNull);

      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }

    // Verify after transaction commit
    final result1 = await db.getAuto('key1');
    final result2 = await db.getAuto('key2');
    final result3 = await db.getAuto('key3');

    expect(String.fromCharCodes(result1!), equals('value1'));
    expect(result2, isNull);
    expect(String.fromCharCodes(result3!), equals('value3'));
  });

  test('Transaction rollback', () async {
    // First put some data with auto transaction
    await db.putAuto('key1', 'initial_value'.codeUnits);

    // Start a transaction and modify data
    final txn = await db.txnStart();
    try {
      await db.put(txn, 'key1', 'modified_value'.codeUnits);
      await db.put(txn, 'key2', 'new_value'.codeUnits);

      // Verify changes within transaction
      var result1 = await db.get(txn, 'key1');
      var result2 = await db.get(txn, 'key2');

      expect(String.fromCharCodes(result1!), equals('modified_value'));
      expect(String.fromCharCodes(result2!), equals('new_value'));

      // Abort transaction instead of committing
      await db.txnAbort(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }

    // Verify that changes were rolled back
    final result1 = await db.getAuto('key1');
    final result2 = await db.getAuto('key2');

    expect(String.fromCharCodes(result1!), equals('initial_value'));
    expect(result2, isNull);
  });

  test('Basic database statistics', () async {
    final txn = await db.txnStart();
    try {
      // Put some data
      await db.put(txn, 'key1', 'value1'.codeUnits);
      await db.put(txn, 'key2', 'value2'.codeUnits);
      await db.put(txn, 'key3', 'value3'.codeUnits);

      // Get stats within same transaction
      final stats = await db.stats(txn);

      expect(stats.entries, equals(3));
      expect(stats.depth, greaterThanOrEqualTo(1));
      expect(stats.leafPages, greaterThan(0));

      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }
  });

  test('Large scale database statistics', () async {
    const int totalEntries = 100000;
    const int averageKeySize = 14; // 'key_' + 10 digits
    const int averageValueSize = 550; // average of random(100-1000)
    const double overheadFactor = 1.5; // B+ tree overhead and fragmentation
    const int batchSize = 1000;
    const int checkInterval = 5000; // Check stats frequency

    final config = LMDBInitConfig.fromEstimate(
        expectedEntries: totalEntries,
        averageKeySize: averageKeySize,
        averageValueSize: averageValueSize,
        overheadFactor: overheadFactor);

    print('Database Configuration:');
    print(
        '- Map Size: ${(config.mapSize / 1024 / 1024).toStringAsFixed(2)} MB');
    print('- Max Possible Entries: ${LMDBConfig.calculateMaxEntries(
      mapSize: config.mapSize,
      averageKeySize: averageKeySize,
      averageValueSize: averageValueSize,
    )}');

    final largeDbPath = path.join(
      Directory.current.path,
      'test_data',
      'large_db_${DateTime.now().millisecondsSinceEpoch}',
    );

    final largeDb = LMDB2();
    await largeDb.init(largeDbPath, config: config);

    final random = Random();

    Uint8List generateRandomValue(int length) {
      return Uint8List.fromList(
          List<int>.generate(length, (i) => random.nextInt(256)));
    }

    try {
      // Initial check with auto-transaction
      var stats = await largeDb.statsAuto();
      expect(stats.entries, equals(0));

      int lastCheckedDepth = 0;

      // Process in batches using explicit transactions
      for (int batchStart = 1;
          batchStart <= totalEntries;
          batchStart += batchSize) {
        final txn = await largeDb.txnStart();
        try {
          final batchEnd = min(batchStart + batchSize - 1, totalEntries);
          for (int i = batchStart; i <= batchEnd; i++) {
            final key = 'key_${i.toString().padLeft(10, '0')}';
            final valueLength = random.nextInt(900) + 100;
            final value = generateRandomValue(valueLength);

            await largeDb.put(txn, key, value);
          }

          await largeDb.txnCommit(txn);

          // Check statistics less frequently using auto-transaction
          if (batchEnd % checkInterval == 0) {
            stats = await largeDb.statsAuto();

            // Verify database consistency
            expect(stats.entries, equals(batchEnd));
            expect(stats.depth, greaterThanOrEqualTo(lastCheckedDepth));
            stats.leafPages + stats.branchPages + stats.overflowPages;
            print('Statistics at $batchEnd entries:');
            print('- Depth: ${stats.depth}');
            print('- Branch Pages: ${stats.branchPages}');
            print('- Leaf Pages: ${stats.leafPages}');
            print('- Overflow Pages: ${stats.overflowPages}');
            print(
                '- Entries per Leaf Page: ${(stats.entries / stats.leafPages).toStringAsFixed(2)}');

            lastCheckedDepth = stats.depth;
          }
        } catch (e) {
          await largeDb.txnAbort(txn);
          rethrow;
        }
      }

      // Final verification using auto-transaction
      final finalStats = await largeDb.statsAuto();
      expect(finalStats.entries, equals(totalEntries));
      expect(finalStats.depth, greaterThan(1));

      print('\nFinal Database Analysis:');
      print(await largeDb.analyzeUsage());
    } finally {
      largeDb.close();
      final dir = Directory(largeDbPath);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  }, timeout: Timeout(Duration(minutes: 5)));
}
