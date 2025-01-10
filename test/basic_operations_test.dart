import 'dart:io';
import 'dart:math';
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
      'db_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
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

  test('UTF-8 string operations', () async {
    final db = LMDB2();
    await db.init(testDir.path);

    // Test with different string types
    final testData = {
      'simple': 'Hello World',
      'unicode': 'Hello 世界 🌍',
      'multiline': 'Line 1\nLine 2\nLine 3',
      'special': 'Special chars: äöüß',
    };

    // Write with explicit transaction
    final writeTxn = await db.txnStart();
    try {
      for (var entry in testData.entries) {
        await db.putUtf8(writeTxn, entry.key, entry.value);
      }
      await db.txnCommit(writeTxn);
    } catch (e) {
      await db.txnAbort(writeTxn);
      rethrow;
    }

    // Read with explicit transaction
    final readTxn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
    try {
      for (var entry in testData.entries) {
        final result = await db.getUtf8(readTxn, entry.key);
        expect(result, equals(entry.value));
      }
      await db.txnCommit(readTxn);
    } catch (e) {
      await db.txnAbort(readTxn);
      rethrow;
    }

    // Test with auto transactions
    await db.putUtf8Auto('auto_key', 'Auto Transaction Test');
    final autoResult = await db.getUtf8Auto('auto_key');
    expect(autoResult, equals('Auto Transaction Test'));

    db.close();
  });
}
