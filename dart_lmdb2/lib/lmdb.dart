/// A high-level Dart interface for LMDB (Lightning Memory-Mapped Database).
///
/// LMDB is a fast key-value store that provides:
/// * Memory-mapped file storage for optimal performance
/// * ACID transactions (depending on given flags) with full CRUD operations
/// * Multiple named databases within a single environment
/// * Concurrent readers with a single writer
/// * Zero-copy lookup for read operations
///
/// This Dart wrapper adds the following features:
/// * Automatic transaction management for simple operations
/// * UTF-8 string support for keys and values
/// * Named databases with automatic handle management
/// * Comprehensive statistics and analysis tools
/// * Safe memory management through FFI
///
/// # Basic Usage
///
/// Simple string operations with automatic transactions:
/// ```dart
/// final db = LMDB();
/// await db.init('/path/to/db');
///
/// // Store and retrieve data
/// await db.putUtf8Auto('key', 'value');
/// final value = await db.getUtf8Auto('key');
///
/// db.close();
/// ```
///
/// # Named Databases
///
/// LMDB supports multiple named databases within a single environment:
/// ```dart
/// // Initialize with support for multiple DBs
/// await db.init('/path/to/db',
///   config: LMDBInitConfig(
///     mapSize: 10 * 1024 * 1024,  // 10 MB
///     maxDbs: 5,  // Support up to 5 named DBs
///   )
/// );
///
/// // Store data in different named databases
/// await db.putUtf8Auto('key', 'value1', dbName: 'users');
/// await db.putUtf8Auto('key', 'value2', dbName: 'settings');
///
/// // Data is separated by database
/// print(await db.getUtf8Auto('key', dbName: 'users'));     // value1
/// print(await db.getUtf8Auto('key', dbName: 'settings'));  // value2
///
/// // List all named databases
/// final databases = await db.listDatabases();
/// ```
///
/// # Transaction Management
///
/// For better control and performance, use explicit transactions:
/// ```dart
/// final txn = await db.txnStart();
/// try {
///   // Multiple operations in one atomic transaction
///   await db.putUtf8(txn, 'key1', 'value1', dbName: 'users');
///   await db.putUtf8(txn, 'key2', 'value2', dbName: 'users');
///   await db.txnCommit(txn);
/// } catch (e) {
///   await db.txnAbort(txn);
///   rethrow;
/// }
/// ```
///
/// Read-only transactions for better concurrency:
/// ```dart
/// final readTxn = await db.txnStart(
///   flags: LMDBFlagSet()..add(MDB_RDONLY)
/// );
/// ```
///
/// # Performance Features
///
/// Optimize for specific use cases:
/// ```dart
/// // High-performance mode (less durability)
/// await db.init('/path/to/db',
///   flags: LMDBFlagSet()
///     ..add(MDB_NOSYNC)      // Don't sync to disk immediately
///     ..add(MDB_WRITEMAP)    // Use write-ahead mapping
/// );
///
/// // Configure map size for expected data volume
/// await db.init('/path/to/db',
///   config: LMDBInitConfig.fromEstimate(
///     expectedEntries: 1000000,
///     averageKeySize: 16,
///     averageValueSize: 64,
///   )
/// );
/// ```
///
/// # LMDB MapSize Behavior
///
/// The MapSize in LMDB determines the maximum database size and behaves as follows:
///
/// 1. Read-Only Access:
/// - Databases can be opened with any MapSize (even smaller) in read-only mode
/// - Perfect for use cases like dictionaries or lookups where only reading is required
/// - The actual DB size can be determined using statsAuto()
///
/// 2. Write Access:
/// - MapSize must be at least as large as the current DB size
/// - Write operations will fail with MDB_MAP_FULL when MapSize limit is reached
/// - MapSize can only be set when opening the DB, not during runtime
///
/// 3. Size Adjustment:
/// - A DB can be reopened with larger MapSize to allow growth
/// - It's recommended to reserve more MapSize than currently needed
/// - Typical pattern: Open read-only to check size -> Close -> Reopen with proper MapSize
///
/// Example Usage:
/// ```dart
///     final db = LMDB();
///     // Open with 100MB initial size
///     await db.init(path, config: LMDBInitConfig(mapSize: 100 * 1024 * 1024));
/// ```
///
/// Note: MapSize can be important for performance and resource management. Choose it based on:
/// - Expected data growth
/// - Available system resources
/// - Application requirements
/// - Even with small MapSize (e.g. 1MB for a 100MB DB), LMDB maintains very good performance !
///
/// # Monitoring and Analysis
///
/// Track database health and performance:
/// ```dart
/// // Get statistics for specific database
/// final stats = await db.statsAuto(dbName: 'users');
/// print('Entries: ${stats.entries}');
/// print('Tree depth: ${stats.depth}');
///
/// // Analyze database efficiency
/// final analysis = await db.analyzeUsage();
/// print(analysis);
///
/// // Monitor all databases
/// final allStats = await db.getAllDatabaseStats();
/// allStats.forEach((dbName, stats) {
///   print('$dbName: ${stats.entries} entries');
/// });
/// ```
///
/// # Common Use Cases
///
/// 1. Simple Key-Value Store:
/// * Use automatic methods (putUtf8Auto, getUtf8Auto)
/// * Perfect for configuration storage, caching
///
/// 2. Multiple Data Types:
/// * Use named databases to separate different data types
/// * Each database can have its own configuration
///
/// 3. High-Performance Requirements:
/// * Use explicit transactions for batching
/// * Configure flag sets for specific durability needs
/// * Adjust map size based on data volume
///
/// 4. Concurrent Access:
/// * Multiple readers can access simultaneously
/// * Use read-only transactions when possible
/// * Single writer ensures data consistency
///
/// # Best Practices
///
/// * Always close the database when done
/// * Use try-catch blocks with transactions
/// * Configure map size appropriately
/// * Monitor database statistics for optimization
/// * Use named databases for data organization
/// * Consider using read-only transactions for queries
/// # Error Handling
///
/// The library provides specific error handling through LMDBException:
/// ```dart
/// try {
///   await db.putUtf8Auto('key', 'value');
/// } catch (e) {
///   if (e is LMDBException) {
///     print('LMDB Error: ${e.errorString}');
///     print('Error code: ${e.errorCode}');
///   }
/// }
/// ```
///
/// # Database Organization
///
/// Named databases can be used to organize different types of data:
/// ```dart
/// // Initialize with multiple databases
/// await db.init('/path/to/db',
///   config: LMDBInitConfig(maxDbs: 5)
/// );
///
/// // Users database
/// await db.putUtf8Auto(
///   'user:123',
///   jsonEncode({'name': 'John', 'age': 30}),
///   dbName: 'users'
/// );
///
/// // Settings database
/// await db.putUtf8Auto(
///   'theme',
///   jsonEncode({'dark': true, 'fontSize': 14}),
///   dbName: 'settings'
/// );
///
/// // Logs database
/// await db.putUtf8Auto(
///   DateTime.now().toIso8601String(),
///   'Application started',
///   dbName: 'logs'
/// );
/// ```
///
/// # Database Maintenance
///
/// Regular maintenance tasks:
/// ```dart
/// // Ensure data is synced to disk
/// await db.sync(true);
///
/// // Check database statistics
/// final stats = await db.getEnvironmentStats();
/// if (stats.overflowPages > 0) {
///   print('Warning: Database has overflow pages');
/// }
///
/// // Monitor database growth
/// final efficiency = LMDBConfig.analyzeEfficiency(stats);
/// if (!efficiency.isWellBalanced) {
///   print('Warning: B+ tree needs optimization');
/// }
/// ```
///
/// # Platform Specifics
///
/// LMDB behavior can vary by platform:
/// * Windows: Some features like MDB_WRITEMAP might not work as expected
/// * Linux/Unix: Full feature support, including file permissions
/// * macOS: Similar to Linux/Unix with some performance differences
///
/// Configure accordingly:
/// ```dart
/// if (Platform.isWindows) {
///   await db.init('/path/to/db',
///     flags: LMDBFlagSet()..add(MDB_NOSYNC)  // Skip MDB_WRITEMAP on Windows
///   );
/// } else {
///   await db.init('/path/to/db',
///     flags: LMDBFlagSet()
///       ..add(MDB_NOSYNC)
///       ..add(MDB_WRITEMAP),
///     config: LMDBInitConfig(mode: '644')  // Unix permissions
///   );
/// }
/// ```
///
/// # Performance Optimization
///
/// Tips for optimal performance:
/// * Use appropriate map sizes to avoid reallocations
/// * Batch operations in transactions
/// * Use read-only transactions for queries
/// * Consider durability vs speed tradeoffs
///
/// Example of batch processing:
/// ```dart
/// final txn = await db.txnStart();
/// try {
///   for (var i = 0; i < 1000; i++) {
///     await db.putUtf8(
///       txn,
///       'key$i',
///       'value$i',
///       dbName: 'batch_data'
///     );
///   }
///   await db.txnCommit(txn);
/// } catch (e) {
///   await db.txnAbort(txn);
///   rethrow;
/// }
/// ```
///
/// # Memory Management
///
/// LMDB uses memory-mapped files, so consider:
/// * Set appropriate map sizes for your data
/// * Monitor system memory usage
/// * Use efficient key/value sizes
/// * Clean up with dispose() when done
///
/// Example of memory-conscious initialization:
/// ```dart
/// await db.init('/path/to/db',
///   config: LMDBInitConfig(
///     mapSize: LMDBConfig.calculateMapSize(
///       expectedEntries: 1000000,
///       averageKeySize: 16,
///       averageValueSize: 64,
///       overheadFactor: 1.5
///     )
///   )
/// );
/// ```
library;

export 'src/database_stats.dart';
export 'src/lmdb_class.dart';
export 'src/lmdb_config.dart';
export 'src/lmdb_constants.dart';
export 'src/lmdb_cursor.dart';
export 'src/lmdb_exception.dart';
export 'src/lmdb_flags.dart';
export 'src/generated_bindings.dart' show MDB_txn;
