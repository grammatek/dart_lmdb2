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
    testDir = Directory(path.join(
      Directory.current.path,
      'test_data',
      'named_db_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
    ));

    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);

    dbPath = testDir.path;
    db = LMDB2();

    try {
      final config = LMDBInitConfig(
        mapSize: LMDBConfig.minMapSize,
        maxDbs: 5, // Support multiple named databases
      );
      await db.init(dbPath, config: config);
    } catch (e) {
      testDir.deleteSync(recursive: true);
      rethrow;
    }
  });

  tearDown(() {
    db.close();
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  test('Create and use multiple named databases', () async {
    // Use different named databases
    await db.putAuto('key1', 'value1'.codeUnits, dbName: 'db1');
    await db.putAuto('key1', 'value2'.codeUnits, dbName: 'db2');
    await db.putAuto('key1', 'value3'.codeUnits); // default database

    // Verify values in different databases
    final result1 = await db.getAuto('key1', dbName: 'db1');
    final result2 = await db.getAuto('key1', dbName: 'db2');
    final result3 = await db.getAuto('key1'); // default database

    expect(String.fromCharCodes(result1!), equals('value1'));
    expect(String.fromCharCodes(result2!), equals('value2'));
    expect(String.fromCharCodes(result3!), equals('value3'));
  });

  test('List named databases', () async {
    // Create several named databases
    await db.putAuto('key', 'value'.codeUnits, dbName: 'db1');
    await db.putAuto('key', 'value'.codeUnits, dbName: 'db2');
    await db.putAuto('key', 'value'.codeUnits, dbName: 'db3');

    final databases = await db.listDatabases();
    expect(databases, containsAll(['db1', 'db2', 'db3']));
  });

  test('Database isolation', () async {
    // Put data in different databases
    await db.putAuto('key', 'value1'.codeUnits, dbName: 'db1');
    await db.putAuto('key', 'value2'.codeUnits, dbName: 'db2');

    // Delete from one database shouldn't affect others
    await db.deleteAuto('key', dbName: 'db1');

    final result1 = await db.getAuto('key', dbName: 'db1');
    final result2 = await db.getAuto('key', dbName: 'db2');

    expect(result1, isNull);
    expect(String.fromCharCodes(result2!), equals('value2'));
  });
}
