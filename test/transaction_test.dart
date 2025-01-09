import 'dart:io';
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
}
