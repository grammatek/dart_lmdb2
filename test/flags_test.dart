import 'dart:io';
import 'dart:math';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:dart_lmdb2/dart_lmdb2.dart';

void main() {
  late Directory testDir;

  setUp(() {
    testDir = Directory(path.join(
      Directory.current.path,
      'test_data',
      'flags_db_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
    ));

    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);
  });

  tearDown(() {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  test('Read-only database access', () async {
    final dbPath = path.join(testDir.path, 'readonly_test');

    // First create and populate database
    final writeDb = LMDB2();
    await writeDb.init(
      dbPath,
      config: LMDBInitConfig(mapSize: LMDBConfig.minMapSize, mode: "0o666"),
    );
    await writeDb.putAuto('key', 'value'.codeUnits);
    writeDb.close();

    // Now open in read-only mode
    final readDb = LMDB2();
    final readOnlyFlags = LMDBFlagSet.readOnly;

    await readDb.init(dbPath,
        config: LMDBInitConfig(
          mapSize: LMDBConfig.minMapSize,
          maxDbs: 1,
          mode: "0644",
        ),
        flags: readOnlyFlags);

    // Should be able to read
    final result = await readDb.getAuto('key');
    expect(String.fromCharCodes(result!), equals('value'));

    // Write operations should fail
    expect(
      () => readDb.putAuto('key2', 'value2'.codeUnits),
      throwsA(isA<LMDBException>()),
    );

    readDb.close();
  });

  test('High performance mode', () async {
    final db = LMDB2();
    final highPerfFlags = LMDBFlagSet.highPerformance;

    await db.init(
      testDir.path,
      config: LMDBInitConfig(
        mapSize: LMDBConfig.minMapSize,
        maxDbs: 1,
      ),
      flags: highPerfFlags,
    );

    // Perform rapid writes
    final txn = await db.txnStart();
    try {
      for (int i = 0; i < 1000; i++) {
        await db.put(txn, 'key$i', 'value$i'.codeUnits);
      }
      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }

    // Force sync to ensure data is written
    await db.sync(true);

    // Verify data
    for (int i = 0; i < 1000; i++) {
      final result = await db.getAuto('key$i');
      expect(String.fromCharCodes(result!), equals('value$i'));
    }

    db.close();
  });

  test('No sub-directory mode', () async {
    final dbFile = File(path.join(testDir.path, 'data.mdb'));
    final lockFile = File(path.join(testDir.path, 'data.mdb-lock'));

    final db = LMDB2();
    final noSubdirFlags = LMDBFlagSet()..add(MDB_NOSUBDIR);

    await db.init(dbFile.path, flags: noSubdirFlags);

    await db.putAuto('key', 'value'.codeUnits);
    final result = await db.getAuto('key');

    expect(String.fromCharCodes(result!), equals('value'));
    expect(dbFile.existsSync(), isTrue);
    expect(lockFile.existsSync(), isTrue);

    db.close();
  });

  test('Combined flags test', () async {
    final dbPath = path.join(testDir.path, 'combined_flags');

    // Create with write access
    final writeDb = LMDB2();
    final writeFlags = LMDBFlagSet()
      ..add(MDB_NOSUBDIR)
      ..add(MDB_NOSYNC); // Combine multiple flags

    await writeDb.init(
      dbPath,
      config: LMDBInitConfig(
        mapSize: LMDBConfig.minMapSize,
        maxDbs: 1,
      ),
      flags: writeFlags,
    );

    await writeDb.putAuto('key', 'value'.codeUnits);
    writeDb.close();

    // Open same file read-only
    final readDb = LMDB2();
    final readFlags = LMDBFlagSet()
      ..add(MDB_NOSUBDIR)
      ..add(MDB_RDONLY);

    await readDb.init(
      dbPath,
      config: LMDBInitConfig(
        mapSize: LMDBConfig.minMapSize,
        maxDbs: 1,
      ),
      flags: readFlags,
    );

    final result = await readDb.getAuto('key');
    expect(String.fromCharCodes(result!), equals('value'));

    // Write should fail
    expect(
      () => readDb.putAuto('key2', 'value2'.codeUnits),
      throwsA(isA<LMDBException>()),
    );

    readDb.close();
  });
}
