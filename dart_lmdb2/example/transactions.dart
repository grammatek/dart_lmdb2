import 'package:dart_lmdb2/lmdb.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// This example shows how to use explicit transactions for batch operations.
void main() async {
  final db = LMDB();
  final dbPath = path.join(Directory.current.path, 'example_db');
  await db.init(dbPath);

  final txn = await db.txnStart();
  try {
    // Batch insert
    for (int i = 0; i < 1000; i++) {
      await db.put(txn, 'key$i', 'value$i'.codeUnits);
    }

    // Read within same transaction
    final value = await db.get(txn, 'key500');
    print('Value: ${String.fromCharCodes(value!)}');

    await db.txnCommit(txn);
  } catch (e) {
    await db.txnAbort(txn);
    rethrow;
  } finally {
    db.close();
    // Cleanup example database
    if (Directory(dbPath).existsSync()) {
      Directory(dbPath).deleteSync(recursive: true);
    }
  }
}
