/// LMDB (Lightning Memory-Mapped Database) wrapper for Dart.
///
/// This library provides both high-level convenience methods and low-level
/// transaction control for LMDB operations.
///
/// Basic usage with auto-transactions:
///
/// ```dart
/// final db = LMDB2();
/// await db.init('path/to/db');
///
/// // Write data
/// await db.putAuto('key', 'value'.codeUnits);
///
/// // Read data
/// final result = await db.getAuto('key');
/// print(String.fromCharCodes(result!));
/// ```
///
/// Using explicit transactions for batch operations:
///
/// ```dart
/// final txn = await db.txnStart();
/// try {
///   await db.put(txn, 'key1', 'value1'.codeUnits);
///   await db.put(txn, 'key2', 'value2'.codeUnits);
///   await db.putUtf8(txn, 'key2', 'Hello world');
///   await db.txnCommit(txn);
/// } catch (e) {
///   await db.txnAbort(txn);
///   rethrow;
/// }
/// ```
///
/// See also:
/// * [LMDB2] - The main database class
/// * [LMDBConfig] - Configuration utilities
/// * [DatabaseStats] - Statistics about the database
/// * [LMDBFlagSet] - Type-safe flag management
/// * Example code in `example/dart_lmdb2_example.dart`
///
library;

export 'src/lmdb2.dart';
export 'src/lmdb_config.dart';
export 'src/database_stats.dart';
export 'src/lmdb_exception.dart';
export 'src/lmdb_flags.dart';
export 'src/lmdb_constants.dart';
