import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'generated_bindings.dart';
import 'lmdb_exception.dart';
import 'database_stats.dart';
import 'lmdb_config.dart';
import 'lmdb_cursor.dart';
import 'lmdb_flags.dart';
import 'lmdb_native.dart';

/// A high-level Dart interface for LMDB (Lightning Memory-Mapped Database).
///
/// LMDB provides a Dart-friendly API for interacting with LMDB, featuring:
/// * Automatic transaction management
/// * UTF-8 string support
/// * Named databases
/// * Comprehensive statistics and analysis
///
/// Basic usage:
/// ```dart
/// final db = LMDB();
///
/// // Initialize the database
/// await db.init('/path/to/db');
///
/// // Store some data
/// await db.putUtf8Auto('key', 'value');
///
/// // Retrieve data
/// final value = await db.getUtf8Auto('key');
/// print(value); // Prints: value
///
/// // Clean up
/// db.close();
/// ```
///
/// Advanced usage with explicit transactions:
/// ```dart
/// final db = LMDB();
/// await db.init('/path/to/db');
///
/// final txn = await db.txnStart();
/// try {
///   await db.putUtf8(txn, 'key1', 'value1');
///   await db.putUtf8(txn, 'key2', 'value2');
///   await db.txnCommit(txn);
/// } catch (e) {
///   await db.txnAbort(txn);
///   rethrow;
/// }
/// ```
class LMDB {
  /// Native library bindings
  late final NativeLibrary _lib;

  /// The native LMDB environment pointer
  Pointer<MDB_env>? _env;

  /// Constants for internal usage
  static const String _dbNamesKey = '__db_names__';
  static const String _defaultMode = "0664";
  static const int _defaultMaxDbs = 1;

  /// Error messages
  static const String _errDbNotInitialized = 'Database not initialized';

  /// Cache for database handles
  final Map<String, int> _dbiCache = {};

  /// Checks if the database has been initialized.
  bool get isInitialized => _env != null;

  /// Safe accessor for the environment pointer
  ///
  /// Throws [StateError] if the database is closed or not initialized
  Pointer<MDB_env> get env {
    if (_env == null) {
      throw StateError('Database not initialized');
    }
    return _env!;
  }

  /// Creates a new LMDB instance and loads the native library.
  ///
  /// Note: Call [init] before performing any database operations.
  LMDB() {
    _lib = LMDBNative.instance.lib;
  }

  /// Helper for FFI memory management with specific pointer types
  ///
  /// [action] The action to perform with the allocated pointer
  /// [pointer] The pointer to be freed after use
  /// [T] The return type of the action
  /// [P] The specific pointer type being used
  T _withAllocated<T, P extends NativeType>(
    T Function(Pointer<P> ptr) action,
    Pointer<P> pointer,
  ) {
    try {
      return action(pointer);
    } finally {
      calloc.free(pointer);
    }
  }

  /// Initializes a new LMDB environment at the specified path with optional
  /// configuration and flags.
  ///
  /// The [dbPath] parameter specifies where the database should be created or
  /// opened.
  /// If the directory doesn't exist, it will be created automatically.
  ///
  /// The optional [config] parameter allows fine-tuning of the database
  /// environment:
  /// ```dart
  /// await db.init('/path/to/db',
  ///   config: LMDBInitConfig(
  ///     mapSize: 10 * 1024 * 1024,  // 10 MB mapped to memory
  ///     maxDbs: 5,                  // Support up to 5 named databases
  ///     mode: "0644",               // File permissions
  ///   )
  /// );
  /// ```
  ///
  /// The optional [flags] parameter enables specific LMDB features:
  /// ```dart
  /// await db.init('/path/to/db',
  ///   flags: LMDBFlagSet()
  ///   ..add(MDB_NOSUBDIR) // Use path as filename
  ///   ..add(MDB_NOSYNC) // Don't sync to disk immediately
  /// );
  /// ````
  ///
  /// Common flag combinations are available as presets:
  /// ```dart
  /// await db.init('/path/to/db', flags: LMDBFlagSet.readOnly);
  /// await db.init('/path/to/db', flags: LMDBFlagSet.highPerformance);
  /// ````
  ///
  /// If no [config] is provided, default values will be used:
  /// - mapSize: Minimum allowed size (typically 10MB)
  /// - maxDbs: 1 (single unnamed database)
  /// - mode: "0664" (rw-rw-r--)
  ///
  /// Throws [StateError] if:
  /// - Database is already initialized (call [close] first)
  /// - Database is closed (create a new instance)
  ///
  /// Throws [LMDBException] if:
  /// - Environment creation fails (insufficient permissions, invalid path)
  /// - Map size setting fails (invalid size)
  /// - Environment opening fails (file system issues, incompatible flags)
  ///
  /// Example usage:
  /// ```dart
  /// final db = LMDB();
  ///
  /// // Basic initialization
  /// await db.init('/path/to/db');
  ///
  /// // With custom configuration
  /// await db.init('/path/to/db',
  ///   config: LMDBInitConfig(mapSize: 1024 * 1024 * 1024), // 1GB
  ///   flags: LMDBFlagSet()..add(MDB_NOSUBDIR)
  /// );
  ///
  /// // Don't forget to close when done
  /// db.close();
  /// ```
  Future<void> init(
    String dbPath, {
    LMDBInitConfig? config,
    LMDBFlagSet? flags,
  }) async {
    if (_env != null) {
      close();
    }

    final effectiveFlags = flags ?? LMDBFlagSet.defaultFlags;
    final effectiveConfig = config ??
        LMDBInitConfig(
          mapSize: LMDBConfig.minMapSize,
          maxDbs: _defaultMaxDbs,
          mode: _defaultMode,
        );

    // Determine if we're in NOSUBDIR mode
    if (effectiveFlags.contains(MDB_NOSUBDIR)) {
      // For NOSUBDIR mode, ensure parent directory exists
      final parentDir = Directory(path.dirname(dbPath));
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
    } else {
      // Normal mode: create directory if it doesn't exist
      final dir = Directory(dbPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }

    return _withAllocated<void, Pointer<MDB_env>>((envPtr) {
      final result = _lib.mdb_env_create(envPtr);
      if (result != 0) {
        throw LMDBException('Failed to create environment', result);
      }

      _env = envPtr.value;

      try {
        final setSizeResult = _lib.mdb_env_set_mapsize(
          env,
          effectiveConfig.mapSize,
        );

        if (setSizeResult != 0) {
          throw LMDBException('Failed to set map size', setSizeResult);
        }

        if (effectiveConfig.maxDbs > 1) {
          final setDbsResult = _lib.mdb_env_set_maxdbs(
            env,
            effectiveConfig.maxDbs,
          );

          if (setDbsResult != 0) {
            throw LMDBException('Failed to set max DBs', setDbsResult);
          }
        }

        final pathPtr = dbPath.toNativeUtf8();
        try {
          final openResult = _lib.mdb_env_open(
            env,
            pathPtr.cast(),
            effectiveFlags.value,
            effectiveConfig.modeAsInt,
          );

          if (openResult != 0) {
            throw LMDBException('Failed to open environment', openResult);
          }
        } finally {
          calloc.free(pathPtr);
        }
      } catch (e) {
        _lib.mdb_env_close(_env!);
        _env = null;
        rethrow;
      }
    }, calloc<Pointer<MDB_env>>());
  }

  /// Closes the database and releases all resources.
  ///
  /// After calling close, the database must be re-initialized
  /// before it can be used again.
  void close() {
    if (_env != null) {
      _lib.mdb_env_close(_env!);
      _env = null;
      _dbiCache.clear();
    }
  }

  /// Analyzes current database usage and returns a formatted report.
  ///
  /// Example:
  /// ```dart
  /// final analysis = await db.analyzeUsage();
  /// print(analysis);
  /// // Prints detailed statistics about database structure
  /// ```
  Future<String> analyzeUsage() async {
    final stats = await getStats();
    return LMDBConfig.analyzeUsage(stats);
  }

  /// Starts a new LMDB transaction.
  ///
  /// A transaction represents a coherent set of changes to the database.
  /// All database operations must be performed within a transaction.
  ///
  /// Parameters:
  /// * [parent] - Optional parent transaction for nested transactions
  /// * [flags] - Optional flags to modify transaction behavior
  ///
  /// Common flags:
  /// * MDB_RDONLY - Read-only transaction (better performance, multiple readers allowed)
  /// * MDB_NOSYNC - Don't sync on commit (better performance but less safe)
  ///
  /// Example usage patterns:
  /// ```dart
  /// // 1. Basic read-write transaction
  /// final txn = await db.txnStart();
  /// try {
  ///   await db.putUtf8(txn, 'key', 'value');
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  ///
  /// // 2. Read-only transaction
  /// final readTxn = await db.txnStart(
  ///   flags: LMDBFlagSet()..add(MDB_RDONLY)
  /// );
  /// try {
  ///   final value = await db.getUtf8(readTxn, 'key');
  ///   await db.txnCommit(readTxn);
  /// } catch (e) {
  ///   await db.txnAbort(readTxn);
  ///   rethrow;
  /// }
  ///
  /// // 3. Nested transaction
  /// final parentTxn = await db.txnStart();
  /// try {
  ///   await db.putUtf8(parentTxn, 'key1', 'value1');
  ///
  ///   // Start a child transaction
  ///   final childTxn = await db.txnStart(parent: parentTxn);
  ///   try {
  ///     await db.putUtf8(childTxn, 'key2', 'value2');
  ///     await db.txnCommit(childTxn);
  ///   } catch (e) {
  ///     await db.txnAbort(childTxn);
  ///     rethrow;
  ///   }
  ///
  ///   await db.txnCommit(parentTxn);
  /// } catch (e) {
  ///   await db.txnAbort(parentTxn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Important notes:
  /// * Always pair txnStart with either txnCommit or txnAbort
  /// * Use try-catch blocks to ensure proper transaction handling
  /// * Read-only transactions can run concurrently
  /// * Only one write transaction can be active at a time
  /// * Child transactions can only be created from write transactions
  /// * Child transactions must be committed/aborted before parent transactions
  ///
  /// Performance tips:
  /// * Use read-only transactions when possible
  /// * Keep transactions as short as possible
  /// * Consider using MDB_NOSYNC for better write performance
  /// * Use the Auto methods for simple operations
  ///
  /// Throws [StateError] if database is not initialized
  /// Throws [LMDBException] if transaction cannot be started
  Future<Pointer<MDB_txn>> txnStart({
    Pointer<MDB_txn>? parent,
    LMDBFlagSet? flags,
  }) async {
    final currentEnv = env;
    final txnPtr = calloc<Pointer<MDB_txn>>();

    try {
      final result = _lib.mdb_txn_begin(
        currentEnv,
        parent ?? nullptr,
        flags?.value ?? LMDBFlagSet.defaultFlags.value,
        txnPtr,
      );

      if (result != 0) {
        throw LMDBException('Failed to start transaction', result);
      }

      return txnPtr.value;
    } finally {
      calloc.free(txnPtr);
    }
  }

  /// Commits a transaction and makes all its changes permanent.
  ///
  /// After a successful commit:
  /// * All changes made in the transaction become permanent
  /// * The transaction handle becomes invalid
  /// * Child transactions (if any) become invalid
  ///
  /// Parameters:
  /// * [txn] - Transaction to commit
  ///
  /// Example with error handling:
  /// ```dart
  /// final txn = await db.txnStart();
  /// try {
  ///   // Perform multiple operations in one transaction
  ///   await db.putUtf8(txn, 'user:1', '{"name": "John"}');
  ///   await db.putUtf8(txn, 'user:2', '{"name": "Jane"}');
  ///
  ///   // Make all changes permanent
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   // On any error, abort the transaction
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Important notes:
  /// * The transaction handle must not be used after commit
  /// * Always use try-catch with txnAbort in the catch block
  /// * Commit is atomic - either all changes succeed or none do
  ///
  /// Throws [StateError] if database is not initialized
  /// Throws [LMDBException] if commit fails
  Future<void> txnCommit(Pointer<MDB_txn> txn) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final result = _lib.mdb_txn_commit(txn);
    if (result != 0) {
      throw LMDBException('Failed to commit transaction', result);
    }
  }

  /// Aborts a transaction and rolls back all its changes.
  ///
  /// After abort:
  /// * All changes made in the transaction are discarded
  /// * The transaction handle becomes invalid
  /// * Child transactions (if any) become invalid
  ///
  /// Parameters:
  /// * [txn] - Transaction to abort
  ///
  /// Example usage patterns:
  /// ```dart
  /// // 1. In catch block (most common)
  /// final txn = await db.txnStart();
  /// try {
  ///   await db.putUtf8(txn, 'key', 'value');
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  ///
  /// // 2. Explicit rollback
  /// final txn = await db.txnStart();
  /// await db.putUtf8(txn, 'key', 'value');
  /// if (shouldRollback) {
  ///   await db.txnAbort(txn);
  ///   return;
  /// }
  /// await db.txnCommit(txn);
  ///
  /// // 3. In finally block for nested transactions
  /// final parentTxn = await db.txnStart();
  /// try {
  ///   final childTxn = await db.txnStart(parent: parentTxn);
  ///   try {
  ///     // ... operations
  ///     await db.txnCommit(childTxn);
  ///   } finally {
  ///     await db.txnAbort(childTxn);
  ///   }
  ///   await db.txnCommit(parentTxn);
  /// } catch (e) {
  ///   await db.txnAbort(parentTxn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Important notes:
  /// * The transaction handle must not be used after abort
  /// * Abort is safe to call multiple times (subsequent calls have no effect)
  /// * Abort should always be called in catch blocks
  /// * Child transactions must be aborted before parent transactions
  Future<void> txnAbort(Pointer<MDB_txn> txn) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);
    _lib.mdb_txn_abort(txn);
  }

  /// Helper for automatic transaction management
  ///
  /// [action] The action to perform within the transaction
  /// [flags] Optional flags for the transaction
  Future<T> _withTransaction<T>(
    Future<T> Function(Pointer<MDB_txn> txn) action, {
    LMDBFlagSet? flags,
  }) async {
    final txn = await txnStart(flags: flags);
    try {
      final result = await action(txn);
      if (flags?.contains(MDB_RDONLY) ?? false) {
        txnAbort(txn);
      } else {
        await txnCommit(txn);
      }
      return result;
    } catch (e) {
      txnAbort(txn);
      rethrow;
    }
  }

  /// Stores a raw byte value in the database.
  ///
  /// Parameters:
  /// * [txn] - Active transaction
  /// * [key] - String key under which to store the value
  /// * [value] - Raw bytes to store
  /// * [dbName] - Optional named database. If not provided, the default database will be used.
  /// * [flags] - Optional operation flags
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart();
  /// try {
  ///   await db.put(txn, 'key', [1, 2, 3, 4]);
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Throws [StateError] if database is not initialized
  /// Throws [LMDBException] if operation fails
  Future<void> put(
    Pointer<MDB_txn> txn,
    String key,
    List<int> value, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final dbi = await _getDatabase(txn, name: dbName, flags: flags);
    final keyPtr = key.toNativeUtf8();
    final valuePtr = calloc<Uint8>(value.length);

    try {
      final valueList = valuePtr.asTypedList(value.length);
      valueList.setAll(0, value);

      return _withAllocated<void, MDB_val>((keyVal) {
        return _withAllocated<void, MDB_val>((dataVal) {
          keyVal.ref.mv_size = keyPtr.length;
          keyVal.ref.mv_data = keyPtr.cast();

          dataVal.ref.mv_size = value.length;
          dataVal.ref.mv_data = valuePtr.cast();

          final result = _lib.mdb_put(
            txn,
            dbi,
            keyVal,
            dataVal,
            flags?.value ?? 0,
          );

          if (result != 0) {
            throw LMDBException('Failed to put data', result);
          }
        }, calloc<MDB_val>());
      }, calloc<MDB_val>());
    } finally {
      calloc.free(keyPtr);
      calloc.free(valuePtr);
    }
  }

  /// Retrieves a raw byte value from the database.
  ///
  /// Parameters:
  /// * [txn] - Active transaction
  /// * [key] - Key to retrieve
  /// * [dbName] - Optional named database. If not provided, the default database will be used.
  /// * [flags] - Optional operation flags
  ///
  /// Returns the value as byte list, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
  /// try {
  ///   final bytes = await db.get(txn, 'key');
  ///   if (bytes != null) {
  ///     print('Value: $bytes');
  ///   }
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  Future<List<int>?> get(
    Pointer<MDB_txn> txn,
    String key, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final dbi = await _getDatabase(txn, name: dbName, flags: flags);
    final keyPtr = key.toNativeUtf8();

    try {
      return _withAllocated<List<int>?, MDB_val>((keyVal) {
        return _withAllocated<List<int>?, MDB_val>((dataVal) {
          keyVal.ref.mv_size = keyPtr.length;
          keyVal.ref.mv_data = keyPtr.cast();

          final result = _lib.mdb_get(
            txn,
            dbi,
            keyVal,
            dataVal,
          );

          if (result == 0) {
            final data = dataVal.ref.mv_data.cast<Uint8>();
            return data.asTypedList(dataVal.ref.mv_size).toList();
          } else if (result == MDB_NOTFOUND) {
            return null;
          } else {
            throw LMDBException('Failed to get data', result);
          }
        }, calloc<MDB_val>());
      }, calloc<MDB_val>());
    } finally {
      calloc.free(keyPtr);
    }
  }

  /// Deletes a value from the database.
  ///
  /// Parameters:
  /// * [txn] - Active transaction
  /// * [key] - Key to delete
  /// * [dbName] - Optional named database. If not provided, the default database will be used.
  /// * [flags] - Optional operation flags
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart();
  /// try {
  ///   await db.delete(txn, 'key');
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Note: Does not throw if key doesn't exist
  Future<void> delete(
    Pointer<MDB_txn> txn,
    String key, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final dbi = await _getDatabase(txn, name: dbName, flags: flags);
    final keyPtr = key.toNativeUtf8();

    try {
      return _withAllocated<void, MDB_val>((keyVal) {
        keyVal.ref.mv_size = keyPtr.length;
        keyVal.ref.mv_data = keyPtr.cast();

        final result = _lib.mdb_del(
          txn,
          dbi,
          keyVal,
          nullptr,
        );

        if (result != 0 && result != MDB_NOTFOUND) {
          throw LMDBException('Failed to delete data', result);
        }
      }, calloc<MDB_val>());
    } finally {
      calloc.free(keyPtr);
    }
  }

  /// Stores a UTF-8 encoded string value in the database
  ///
  /// The [key] is used as UTF-8 encoded database key.
  /// The [value] string will be UTF-8 encoded before storage.
  ///
  /// The optional [dbName] parameter specifies a named database.
  /// If not provided, the default database will be used.
  ///
  /// The optional [flags] parameter allows setting specific LMDB flags for this operation.
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart();
  /// try {
  ///   await db.putUtf8(txn, 'user_123', '{"name": "John", "age": 30}');
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Throws [StateError] if the database is closed.
  /// Throws [LMDBException] if the operation fails.
  Future<void> putUtf8(
    Pointer<MDB_txn> txn,
    String key,
    String value, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    await put(txn, key, utf8.encode(value), dbName: dbName, flags: flags);
  }

  /// Retrieves a UTF-8 encoded string value from the database
  ///
  /// The [key] is used as UTF-8 encoded database key.
  ///
  /// The optional [dbName] parameter specifies a named database.
  /// If not provided, the default database will be used.
  ///
  /// Returns the decoded UTF-8 string value, or null if the key doesn't exist.
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
  /// try {
  ///   final json = await db.getUtf8(txn, 'user_123');
  ///   if (json != null) {
  ///     final userData = jsonDecode(json);
  ///     print('User name: ${userData['name']}');
  ///   }
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Throws [StateError] if the database is closed.
  /// Throws [LMDBException] if the operation fails.
  /// Throws [FormatException] if the stored data is not valid UTF-8.
  Future<String?> getUtf8(
    Pointer<MDB_txn> txn,
    String key, {
    String? dbName,
  }) async {
    final result = await get(txn, key, dbName: dbName);
    return result != null ? utf8.decode(result) : null;
  }

  /// Convenience methods with automatic transaction management

  /// Stores a raw byte value with automatic transaction management.
  ///
  /// This is a convenience method that handles transaction creation,
  /// commit, and error handling automatically.
  ///
  /// Parameters:
  /// * [key] - Key under which to store the value
  /// * [value] - Raw bytes to store
  /// * [dbName] - Optional named database
  /// * [flags] - Optional operation flags
  ///
  /// Example:
  /// ```dart
  /// // Simple storage without manual transaction handling
  /// await db.putAuto('key', [1, 2, 3, 4]);
  /// ```
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<void> putAuto(
    String key,
    List<int> value, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    return _withTransaction(
      (txn) async => put(txn, key, value, dbName: dbName, flags: flags),
    );
  }

  /// Retrieves a raw byte value with automatic transaction management.
  ///
  /// Uses an automatic read-only transaction.
  ///
  /// Parameters:
  /// * [key] - Key to retrieve
  /// * [dbName] - Optional named database
  ///
  /// Returns the value as byte list, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await db.getAuto('key');
  /// if (bytes != null) {
  ///   print('Retrieved ${bytes.length} bytes');
  /// }
  /// ```
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<List<int>?> getAuto(
    String key, {
    String? dbName,
  }) async {
    return _withTransaction(
      (txn) async => get(txn, key, dbName: dbName),
      flags: LMDBFlagSet.readOnly,
    );
  }

  /// Deletes a value with automatic transaction management.
  ///
  /// Parameters:
  /// * [key] - Key to delete
  /// * [dbName] - Optional named database
  ///
  /// Example:
  /// ```dart
  /// await db.deleteAuto('key');
  /// ```
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<void> deleteAuto(
    String key, {
    String? dbName,
  }) async {
    return _withTransaction(
      (txn) async => delete(txn, key, dbName: dbName),
    );
  }

  /// Stores a UTF-8 string with automatic transaction management.
  ///
  /// Perfect for simple string storage operations where manual
  /// transaction control isn't needed.
  ///
  /// The [key] is used as UTF-8 encoded database key.
  /// The [value] string will be UTF-8 encoded before storage.
  ///
  /// The optional [dbName] parameter specifies a named database.
  /// If not provided, the default database will be used.
  ///
  /// The optional [flags] parameter allows setting specific LMDB flags for this operation.
  ///
  /// This method handles the transaction automatically, including commit and abort
  /// in case of errors.
  ///
  /// Example:
  /// ```dart
  /// // Simple string storage
  /// await db.putUtf8Auto('greeting', 'Hello, World!');
  ///
  /// // Store JSON data
  /// final userData = {'name': 'John', 'age': 30};
  /// await db.putUtf8Auto('user_123', jsonEncode(userData));
  /// ```
  ///
  /// Throws [StateError] if the database is closed.
  /// Throws [LMDBException] if the operation fails.
  Future<void> putUtf8Auto(
    String key,
    String value, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    return _withTransaction((txn) async {
      return putUtf8(txn, key, value, dbName: dbName, flags: flags);
    });
  }

  /// Retrieves a UTF-8 string with automatic transaction management.
  ///
  /// Uses an automatic read-only transaction.
  ///
  /// The [key] is used as UTF-8 encoded database key.
  ///
  /// The optional [dbName] parameter specifies a named database.
  /// If not provided, the default database will be used.
  ///
  /// Returns the decoded UTF-8 string value, or null if the key doesn't exist.
  ///
  /// This method handles the transaction automatically, including commit and abort
  /// in case of errors.
  ///
  /// Example:
  /// ```dart
  /// // Read simple string
  /// final greeting = await db.getUtf8Auto('greeting');
  /// print(greeting); // Prints: Hello, World!
  ///
  /// // Read and parse JSON data
  /// final jsonStr = await db.getUtf8Auto('user_123');
  /// if (jsonStr != null) {
  ///   final userData = jsonDecode(jsonStr);
  ///   print('User name: ${userData['name']}');
  /// }
  /// ```
  ///
  /// Throws [StateError] if the database is closed.
  /// Throws [LMDBException] if the operation fails.
  /// Throws [FormatException] if the stored data is not valid UTF-8.
  Future<String?> getUtf8Auto(
    String key, {
    String? dbName,
  }) async {
    return _withTransaction((txn) async {
      return getUtf8(txn, key, dbName: dbName);
    }, flags: LMDBFlagSet.readOnly);
  }

  /// Gets database statistics with automatic transaction management.
  ///
  /// Parameters:
  /// * [dbName] - Optional named database
  /// * [flags] - Optional operation flags
  ///
  /// Returns detailed statistics about the database structure.
  ///
  /// Example:
  /// ```dart
  /// final stats = await db.statsAuto();
  /// print('Total entries: ${stats.entries}');
  /// print('Tree depth: ${stats.depth}');
  /// ```
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<DatabaseStats> statsAuto({
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    return _withTransaction(
      (txn) async => stats(txn, dbName: dbName, flags: flags),
      flags: LMDBFlagSet.readOnly,
    );
  }

  /// Gets statistics for a specific database using an explicit transaction.
  ///
  /// Parameters:
  /// * [txn] - Active transaction
  /// * [dbName] - Optional named database
  /// * [flags] - Optional operation flags
  ///
  /// Returns detailed database statistics.
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
  /// try {
  ///   final stats = await db.stats(txn);
  ///   print('Entries: ${stats.entries}');
  ///   print('Tree depth: ${stats.depth}');
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<DatabaseStats> stats(
    Pointer<MDB_txn> txn, {
    String? dbName,
    LMDBFlagSet? flags,
  }) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final dbi = await _getDatabase(txn, name: dbName, flags: flags);
    final statPtr = calloc<MDB_stat>();

    try {
      final result = _lib.mdb_stat(
        txn,
        dbi,
        statPtr,
      );

      if (result != 0) {
        throw LMDBException('Failed to get statistics', result);
      }

      return DatabaseStats(
        pageSize: statPtr.ref.ms_psize,
        depth: statPtr.ref.ms_depth,
        branchPages: statPtr.ref.ms_branch_pages,
        leafPages: statPtr.ref.ms_leaf_pages,
        overflowPages: statPtr.ref.ms_overflow_pages,
        entries: statPtr.ref.ms_entries,
      );
    } finally {
      calloc.free(statPtr);
    }
  }

  /// Opens a database with the specified name
  ///
  /// [txn] Transaction to use
  /// [name] Optional database name
  /// [flags] Optional flags for database operations
  ///
  /// Returns database handle (dbi)
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<int> _openDatabase(
    Pointer<MDB_txn> txn, {
    String? name,
    LMDBFlagSet? flags,
  }) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final dbiPtr = calloc<MDB_dbi>();
    try {
      final namePtr = name?.toNativeUtf8();
      try {
        final effectiveFlags = flags ?? LMDBFlagSet.defaultFlags;
        effectiveFlags.add(MDB_CREATE);

        final result = _lib.mdb_dbi_open(
          txn,
          namePtr?.cast() ?? nullptr,
          effectiveFlags.value,
          dbiPtr,
        );

        if (result != 0) {
          throw LMDBException('Failed to open database', result);
        }

        final dbi = dbiPtr.value;
        if (name != null) {
          _dbiCache[name] = dbi;
          await _registerDbName(txn, name);
        }
        return dbi;
      } finally {
        if (namePtr != null) {
          calloc.free(namePtr);
        }
      }
    } finally {
      calloc.free(dbiPtr);
    }
  }

  /// Registers a database name in the internal registry
  Future<void> _registerDbName(Pointer<MDB_txn> txn, String name) async {
    final names = await _getDbNames(txn);
    if (!names.contains(name)) {
      names.add(name);
      await _saveDbNames(txn, names);
    }
  }

  /// Retrieves the list of registered database names
  Future<List<String>> _getDbNames(Pointer<MDB_txn> txn) async {
    final value = await get(txn, _dbNamesKey);
    if (value == null) return [];
    return String.fromCharCodes(value)
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Saves the list of database names
  Future<void> _saveDbNames(Pointer<MDB_txn> txn, List<String> names) async {
    final namesString = names.join(',');
    await put(txn, _dbNamesKey, namesString.codeUnits);
  }

  /// Gets a database handle, using cached value if available
  ///
  /// [txn] Transaction to use
  /// [name] Optional database name
  /// [flags] Optional flags for database operations
  ///
  /// Returns database handle (dbi)
  Future<int> _getDatabase(
    Pointer<MDB_txn> txn, {
    String? name,
    LMDBFlagSet? flags,
  }) async {
    if (name == null) {
      return _openDatabase(txn, flags: flags);
    }

    if (_dbiCache.containsKey(name)) {
      return _dbiCache[name]!;
    }

    return _openDatabase(txn, name: name, flags: flags);
  }

  /// Lists all named databases in the environment.
  ///
  /// Returns a list of database names that have been created.
  /// The default unnamed database is not included in this list.
  ///
  /// Example:
  /// ```dart
  /// final databases = await db.listDatabases();
  /// for (final dbName in databases) {
  ///   print('Found database: $dbName');
  /// }
  /// ```
  Future<List<String>> listDatabases() async {
    final txn = await txnStart();
    try {
      final names = await _getDbNames(txn);
      await txnCommit(txn);
      return names;
    } catch (e) {
      await txnAbort(txn);
      rethrow;
    }
  }

  /// Gets the version string of the LMDB library.
  ///
  /// Returns the version in format "LMDB x.y.z".
  ///
  /// Example:
  /// ```dart
  /// final version = db.getVersion();
  /// print('Using LMDB version: $version');
  /// ```
  String getVersion() {
    final major = calloc<Int>();
    final minor = calloc<Int>();
    final patch = calloc<Int>();

    try {
      final verPtr = _lib.mdb_version(major, minor, patch);
      return verPtr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(major);
      calloc.free(minor);
      calloc.free(patch);
    }
  }

  /// Gets a human-readable error string for an LMDB error code.
  ///
  /// Parameters:
  /// * [err] - LMDB error code
  ///
  /// Returns a descriptive error message.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   // ... some operation
  /// } catch (e) {
  ///   if (e is LMDBException) {
  ///     print('Error: ${db.getErrorString(e.errorCode)}');
  ///   }
  /// }
  /// ```
  String getErrorString(int err) {
    final ptr = _lib.mdb_strerror(err);
    return ptr.cast<Utf8>().toDartString();
  }

  /// Synchronizes the environment to disk.
  ///
  /// Parameters:
  /// * [force] - If true, forces a synchronous flush
  ///
  /// Use this to ensure all changes are written to disk.
  ///
  /// Example:
  /// ```dart
  /// // Normal async sync
  /// await db.sync(false);
  ///
  /// // Force immediate sync
  /// await db.sync(true);
  /// ```
  Future<void> sync(bool force) async {
    final currentEnv = env;
    final result = _lib.mdb_env_sync(currentEnv, force ? 1 : 0);
    if (result != 0) {
      throw LMDBException('Failed to sync environment', result);
    }
  }

  /// Gets statistics for the database specified by its handle
  Future<DatabaseStats> _getStats(Pointer<MDB_txn> txn, int dbi) async {
    final statPtr = calloc<MDB_stat>();
    try {
      final result = _lib.mdb_stat(
        txn,
        dbi,
        statPtr,
      );

      if (result != 0) {
        throw LMDBException('Failed to get statistics', result);
      }

      return DatabaseStats(
        pageSize: statPtr.ref.ms_psize,
        depth: statPtr.ref.ms_depth,
        branchPages: statPtr.ref.ms_branch_pages,
        leafPages: statPtr.ref.ms_leaf_pages,
        overflowPages: statPtr.ref.ms_overflow_pages,
        entries: statPtr.ref.ms_entries,
      );
    } finally {
      calloc.free(statPtr);
    }
  }

  /// Gets statistics for a database.
  ///
  /// If [dbName] is null, returns statistics for the default database.
  /// If [dbName] is provided, returns statistics for the named database.
  ///
  /// Throws [LMDBException] if:
  /// - The database cannot be opened
  /// - Statistics cannot be retrieved
  ///
  /// Example:
  /// ```dart
  /// // Get stats for default database
  /// final defaultStats = await db.getStats();
  ///
  /// // Get stats for named database
  /// final userStats = await db.getStats(dbName: 'users');
  /// ```
  Future<DatabaseStats> getStats({String? dbName}) async {
    final currentEnv = env;
    late final Pointer<MDB_txn> txn;
    try {
      // start transaction (read-only)
      final txnPtr = calloc<Pointer<MDB_txn>>();
      try {
        final result = _lib.mdb_txn_begin(
          currentEnv,
          nullptr,
          MDB_RDONLY,
          txnPtr,
        );

        if (result != 0) {
          throw LMDBException('Failed to start transaction', result);
        }
        txn = txnPtr.value;
      } finally {
        calloc.free(txnPtr);
      }

      // open db read-only
      final dbiPtr = calloc<MDB_dbi>();
      late final int dbi;
      try {
        final result = _lib.mdb_dbi_open(
          txn,
          dbName?.toNativeUtf8().cast() ?? nullptr,
          0,
          dbiPtr,
        );

        if (result != 0) {
          throw LMDBException('Failed to open database', result);
        }
        dbi = dbiPtr.value;
      } finally {
        calloc.free(dbiPtr);
      }

      return _getStats(txn, dbi);
    } finally {
      _lib.mdb_txn_abort(txn);
    }
  }

  /// Gets environment-wide statistics
  ///
  /// Returns statistics for the entire LMDB environment
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<DatabaseStats> getEnvironmentStats() async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final statPtr = calloc<MDB_stat>();
    try {
      final result = _lib.mdb_env_stat(
        env,
        statPtr,
      );

      if (result != 0) {
        throw LMDBException('Failed to get environment statistics', result);
      }

      return DatabaseStats(
        pageSize: statPtr.ref.ms_psize,
        depth: statPtr.ref.ms_depth,
        branchPages: statPtr.ref.ms_branch_pages,
        leafPages: statPtr.ref.ms_leaf_pages,
        overflowPages: statPtr.ref.ms_overflow_pages,
        entries: statPtr.ref.ms_entries,
      );
    } finally {
      calloc.free(statPtr);
    }
  }

  /// Gets statistics for all databases in the environment.
  ///
  /// Returns a map with statistics for:
  /// * 'environment' - Overall environment stats
  /// * 'default' - Default database stats
  /// * Named databases - Stats for each named database
  ///
  /// Example:
  /// ```dart
  /// final allStats = await db.getAllDatabaseStats();
  /// print('Environment entries: ${allStats['environment']?.entries}');
  /// print('Default DB entries: ${allStats['default']?.entries}');
  ///
  /// // Stats for named databases
  /// allStats.forEach((name, stats) {
  ///   if (name != 'environment' && name != 'default') {
  ///     print('DB $name entries: ${stats.entries}');
  ///   }
  /// });
  /// ```
  ///
  /// Throws [StateError] if database is closed
  /// Throws [LMDBException] if operation fails
  Future<Map<String, DatabaseStats>> getAllDatabaseStats() async {
    final statistics = <String, DatabaseStats>{};

    return _withTransaction((txn) async {
      // Get environment stats
      statistics['environment'] = await getEnvironmentStats();

      // Get stats for default DB
      statistics['default'] = await stats(txn);

      // Get stats for all named DBs
      final names = await _getDbNames(txn);
      for (final name in names) {
        statistics[name] = await stats(txn, dbName: name);
      }

      return statistics;
    }, flags: LMDBFlagSet.readOnly);
  }

  /// Opens a new cursor for the specified database
  ///
  /// Parameters:
  /// * [txn] - Active transaction
  /// * [dbName] - Optional named database
  ///
  /// Returns a cursor that must be closed with [cursorClose]
  ///
  /// Example:
  /// ```dart
  /// final txn = await db.txnStart();
  /// try {
  ///   final cursor = await db.cursorOpen(txn);
  ///   try {
  ///     // Use cursor...
  ///   } finally {
  ///     db.cursorClose(cursor);
  ///   }
  ///   await db.txnCommit(txn);
  /// } catch (e) {
  ///   await db.txnAbort(txn);
  ///   rethrow;
  /// }
  /// ```
  ///
  Future<Pointer<MDB_cursor>> cursorOpen(
    Pointer<MDB_txn> txn, {
    String? dbName,
  }) async {
    if (!isInitialized) throw StateError(_errDbNotInitialized);

    final dbi = await _getDatabase(txn, name: dbName);
    final cursorPtr = calloc<Pointer<MDB_cursor>>();

    try {
      final result = _lib.mdb_cursor_open(txn, dbi, cursorPtr);
      if (result != 0) {
        throw LMDBException('Failed to open cursor', result);
      }
      return cursorPtr.value;
    } finally {
      calloc.free(cursorPtr);
    }
  }

  /// Closes a cursor
  ///
  /// The cursor must not be used after closing.
  void cursorClose(Pointer<MDB_cursor> cursor) {
    _lib.mdb_cursor_close(cursor);
  }

  /// Positions cursor and retrieves data
  ///
  /// Parameters:
  /// * [cursor] - Active cursor
  /// * [key] - Optional key for positioning operations
  /// * [operation] - Cursor operation to perform
  ///
  /// Returns the entry at cursor position, or null if no data was found
  ///
  /// Example:
  /// ```dart
  /// // Get first entry
  /// final firstEntry = await db.cursorGet(cursor, null, CursorOp.first);
  ///
  /// // Find specific entry
  /// final entry = await db.cursorGet(
  ///   cursor,
  ///   utf8.encode('searchKey'),
  ///   CursorOp.setRange
  /// );
  ///
  /// // Iterate through entries
  /// var entry = await db.cursorGet(cursor, null, CursorOp.first);
  /// while (entry != null) {
  ///   print('Found: ${entry.toString()}');
  ///   entry = await db.cursorGet(cursor, null, CursorOp.next);
  /// }
  /// ```
  Future<CursorEntry?> cursorGet(
    Pointer<MDB_cursor> cursor,
    List<int>? key,
    CursorOp operation,
  ) async {
    final keyVal = calloc<MDB_val>();
    final dataVal = calloc<MDB_val>();

    try {
      if (key != null) {
        final keyPtr = calloc<Uint8>(key.length);
        try {
          final keyList = keyPtr.asTypedList(key.length);
          keyList.setAll(0, key);

          keyVal.ref.mv_size = key.length;
          keyVal.ref.mv_data = keyPtr.cast();

          final result =
              _lib.mdb_cursor_get(cursor, keyVal, dataVal, operation.value);

          if (result == MDB_NOTFOUND) return null;
          if (result != 0) {
            throw LMDBException('Cursor operation failed', result);
          }

          return CursorEntry(
            key: keyVal.ref.mv_data
                .cast<Uint8>()
                .asTypedList(keyVal.ref.mv_size)
                .toList(),
            data: dataVal.ref.mv_data
                .cast<Uint8>()
                .asTypedList(dataVal.ref.mv_size)
                .toList(),
          );
        } finally {
          calloc.free(keyPtr);
        }
      } else {
        final result =
            _lib.mdb_cursor_get(cursor, keyVal, dataVal, operation.value);

        if (result == MDB_NOTFOUND) return null;
        if (result != 0) {
          throw LMDBException('Cursor operation failed', result);
        }

        return CursorEntry(
          key: keyVal.ref.mv_data
              .cast<Uint8>()
              .asTypedList(keyVal.ref.mv_size)
              .toList(),
          data: dataVal.ref.mv_data
              .cast<Uint8>()
              .asTypedList(dataVal.ref.mv_size)
              .toList(),
        );
      }
    } finally {
      calloc.free(keyVal);
      calloc.free(dataVal);
    }
  }

  /// Stores data at current cursor position
  ///
  /// Parameters:
  /// * [cursor] - Active cursor
  /// * [key] - Key to store
  /// * [value] - Value to store
  /// * [flags] - Optional operation flags
  ///
  /// Example:
  /// ```dart
  /// await db.cursorPut(
  ///   cursor,
  ///   utf8.encode('key'),
  ///   utf8.encode('value'),
  ///   0
  /// );
  /// ```
  Future<void> cursorPut(
    Pointer<MDB_cursor> cursor,
    List<int> key,
    List<int> value,
    int flags,
  ) async {
    final keyPtr = calloc<Uint8>(key.length);
    final valuePtr = calloc<Uint8>(value.length);

    try {
      final keyList = keyPtr.asTypedList(key.length);
      keyList.setAll(0, key);

      final valueList = valuePtr.asTypedList(value.length);
      valueList.setAll(0, value);

      return _withAllocated<void, MDB_val>((keyVal) {
        return _withAllocated<void, MDB_val>((dataVal) {
          keyVal.ref.mv_size = key.length;
          keyVal.ref.mv_data = keyPtr.cast();

          dataVal.ref.mv_size = value.length;
          dataVal.ref.mv_data = valuePtr.cast();

          final result = _lib.mdb_cursor_put(
            cursor,
            keyVal,
            dataVal,
            flags,
          );

          if (result != 0) {
            throw LMDBException('Failed to put cursor data', result);
          }
        }, calloc<MDB_val>());
      }, calloc<MDB_val>());
    } finally {
      calloc.free(keyPtr);
      calloc.free(valuePtr);
    }
  }

  /// Convenience method to store UTF-8 strings using cursor
  ///
  /// Parameters:
  /// * [cursor] - Active cursor
  /// * [key] - Key string
  /// * [value] - Value string
  /// * [flags] - Optional operation flags
  ///
  /// Example:
  /// ```dart
  /// await db.cursorPutUtf8(
  /// cursor,
  /// 'user:123',
  /// '{"name": "John", "age": 30}'
  /// );
  /// ```
  Future<void> cursorPutUtf8(
      Pointer<MDB_cursor> cursor, String key, String value,
      [int flags = 0]) async {
    return cursorPut(
      cursor,
      utf8.encode(key),
      utf8.encode(value),
      flags,
    );
  }

  /// Deletes the entry at current cursor position
  ///
  /// Parameters:
  /// * [cursor] - Active cursor
  /// * [flags] - Optional operation flags
  ///
  /// Example:
  /// ```dart
  /// // Position cursor and delete entry
  /// final entry = await db.cursorGet(cursor, null, CursorOp.first);
  /// if (entry != null) {
  ///   await db.cursorDelete(cursor);
  /// }
  /// ```
  Future<void> cursorDelete(Pointer<MDB_cursor> cursor, [int flags = 0]) async {
    final result = _lib.mdb_cursor_del(cursor, flags);
    if (result != 0) {
      throw LMDBException('Failed to delete at cursor', result);
    }
  }

  /// Helper method to count entries using a cursor
  ///
  /// Parameters:
  /// * [txn] - Active transaction
  /// * [dbName] - Optional named database
  ///
  /// Returns the number of entries in the database
  ///
  /// Example:
  /// ```dart
  /// final count = await db.cursorCount();
  /// print('Database contains $count entries');
  /// ```
  Future<int> cursorCount(
    Pointer<MDB_txn> txn, {
    String? dbName,
  }) async {
    final cursor = await cursorOpen(txn, dbName: dbName);
    try {
      var count = 0;
      var entry = await cursorGet(cursor, null, CursorOp.first);
      while (entry != null) {
        count++;
        entry = await cursorGet(cursor, null, CursorOp.next);
      }
      return count;
    } finally {
      cursorClose(cursor);
    }
  }

  /// Cleans up resources and closes the database.
  ///
  /// This is equivalent to calling [close] and should be called
  /// when the database is no longer needed.
  ///
  /// Example:
  /// ```dart
  /// final db = LMDB();
  /// try {
  ///   await db.init('/path/to/db');
  ///   // ... use database
  /// } finally {
  ///   db.dispose();
  /// }
  /// ```
  void dispose() {
    if (isInitialized) {
      close();
    }
  }
}
