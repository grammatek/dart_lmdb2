import 'package:dart_lmdb2/dart_lmdb2.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

/// This example demonstrates basic CRUD operations using auto-transactions.
void main() async {
  // Create a proper path for the database
  final dbPath = path.join(Directory.current.path, 'example_db');

  // Ensure the directory exists
  final dir = Directory(dbPath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final db = LMDB2();

  try {
    // Initialize with default configuration
    final config = LMDBInitConfig(
      mapSize: LMDBConfig.minMapSize,
      maxDbs: 1,
      envFlags: 0,
      mode: 0664,
    );

    await db.init(dbPath, config: config);

    // Create
    await db.putAuto('user1', '{"name": "John", "age": 30}'.codeUnits);

    // Read
    final userData = await db.getAuto('user1');
    print('User data: ${String.fromCharCodes(userData!)}');

    // Update
    await db.putAuto('user1', '{"name": "John", "age": 31}'.codeUnits);

    // Delete
    await db.deleteAuto('user1');

    print('CRUD operations completed successfully!');
  } finally {
    // Cleanup
    db.close();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      print('Cleaned up database directory');
    }
  }
}
