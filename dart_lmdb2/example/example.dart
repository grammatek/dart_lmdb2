import 'package:dart_lmdb2/lmdb.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

void main() async {
  // Initialize database with custom configuration
  final config = LMDBInitConfig(
    mapSize: 10 * 1024 * 1024, // 10MB
    maxDbs: 1,
    mode: "0664",
  );

  final dbPath = path.join(Directory.current.path, 'example_db');
  final db = LMDB();

  try {
    await db.init(dbPath, config: config);

    // Simple auto-transaction operations
    await db.putAuto('key1', 'Hello World!'.codeUnits);
    final result = await db.getAuto('key1');
    if (result != null) {
      print('Retrieved: ${String.fromCharCodes(result)}');
    }

    // Multiple operations in single transaction
    final txn = await db.txnStart();
    try {
      await db.put(txn, 'key2', 'Transaction'.codeUnits);
      await db.put(txn, 'key3', 'Example'.codeUnits);

      final stats = await db.stats(txn);
      print('\nDatabase Statistics:');
      print('- Total Entries: ${stats.entries}');
      print('- Tree Depth: ${stats.depth}');
      print('- Leaf Pages: ${stats.leafPages}');

      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }

    // Delete with auto-transaction
    await db.deleteAuto('key1');

    // Verify deletion
    final deletedResult = await db.getAuto('key1');
    print(
        '\nAfter deletion: ${deletedResult == null ? 'Entry removed' : 'Entry still exists'}');
  } finally {
    db.close();
    // Cleanup example database
    if (Directory(dbPath).existsSync()) {
      Directory(dbPath).deleteSync(recursive: true);
    }
  }
}
