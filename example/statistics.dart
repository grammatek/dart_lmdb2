import 'package:dart_lmdb2/dart_lmdb2.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// This example demonstrates how to get and analyze database statistics.
void main() async {
  final db = LMDB2();

  // Initialize with custom configuration
  final config = LMDBInitConfig.fromEstimate(
    expectedEntries: 1000000,
    averageKeySize: 16,
    averageValueSize: 100,
  );
  final dbPath = path.join(Directory.current.path, 'example_db');
  await db.init(dbPath, config: config);

  // Insert some test data
  final txn = await db.txnStart();
  try {
    for (int i = 0; i < 10000; i++) {
      await db.put(txn, 'key$i', 'value$i'.codeUnits);
    }

    // Get statistics within transaction
    final stats = await db.stats(txn);
    print('Database Analysis:');
    print('- Total Entries: ${stats.entries}');
    print('- Tree Depth: ${stats.depth}');
    print('- Leaf Pages: ${stats.leafPages}');
    print('- Branch Pages: ${stats.branchPages}');

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
