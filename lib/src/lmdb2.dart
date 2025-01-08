import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'generated_bindings.dart';
import 'lmdb_exception.dart';
import 'database_stats.dart';
import 'lmdb_config.dart';

class LMDB2 {
  late final NativeLibrary _lib;
  late final Pointer<MDB_env> _env;

  LMDB2() {
    _lib = NativeLibrary(_openDynamicLibrary());
  }

  DynamicLibrary _openDynamicLibrary() {
    final libraryPath = _resolveLibraryPath();
    return DynamicLibrary.open(libraryPath);
  }

  String _resolveLibraryPath() {
    final libDir = path.join(Directory.current.path, 'lib', 'src', 'native');

    if (Platform.isWindows) {
      return path.join(libDir, 'lmdb.dll');
    } else if (Platform.isMacOS) {
      return path.join(libDir, 'liblmdb.dylib');
    } else if (Platform.isLinux) {
      return path.join(libDir, 'liblmdb.so');
    }

    throw UnsupportedError('Unsupported platform');
  }

  Future<void> init(String dbPath, {LMDBInitConfig? config}) async {
    final effectiveConfig = config ??
        LMDBInitConfig(
          mapSize: LMDBConfig.minMapSize,
        );
    // Ensure directory exists
    final dir = Directory(dbPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final envPtr = calloc<Pointer<MDB_env>>();

    try {
      // Create environment
      final result = _lib.mdb_env_create(envPtr);
      if (result != 0) {
        throw LMDBException('Failed to create environment', result);
      }

      _env = envPtr.value;

      // Set map size
      final setSizeResult =
          _lib.mdb_env_set_mapsize(_env, effectiveConfig.mapSize);
      if (setSizeResult != 0) {
        throw LMDBException('Failed to set map size', setSizeResult);
      }

      // Open environment
      final pathPtr = dbPath.toNativeUtf8();
      try {
        final openResult = _lib.mdb_env_open(
          _env,
          pathPtr.cast(),
          0, // flags
          0664, // mode (Unix style permissions)
        );
        if (openResult != 0) {
          throw LMDBException('Failed to open environment', openResult);
        }
      } finally {
        calloc.free(pathPtr);
      }
    } catch (e) {
      calloc.free(envPtr);
      rethrow;
    }
  }

  /// Returns analysis of current DB usage
  Future<String> analyzeUsage() async {
    final stats = await getStats();
    return LMDBConfig.analyzeUsage(stats);
  }

  // Transaction handling
  Future<Pointer<MDB_txn>> txnStart() async {
    final txnPtr = calloc<Pointer<MDB_txn>>();
    try {
      final result = _lib.mdb_txn_begin(
        _env,
        nullptr,
        0,
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

  Future<void> txnCommit(Pointer<MDB_txn> txn) async {
    final result = _lib.mdb_txn_commit(txn);
    if (result != 0) {
      throw LMDBException('Failed to commit transaction', result);
    }
  }

  Future<void> txnAbort(Pointer<MDB_txn> txn) async {
    _lib.mdb_txn_abort(txn);
  }

  // Base operations (require transaction)
  Future<void> put(Pointer<MDB_txn> txn, String key, List<int> value) async {
    final dbi = await _openDatabase(txn);
    final keyPtr = key.toNativeUtf8();
    final valuePtr = calloc<Uint8>(value.length);

    try {
      final valueList = valuePtr.asTypedList(value.length);
      valueList.setAll(0, value);

      final keyVal = calloc<MDB_val>();
      final dataVal = calloc<MDB_val>();

      try {
        keyVal.ref.mv_size = keyPtr.length;
        keyVal.ref.mv_data = keyPtr.cast();

        dataVal.ref.mv_size = value.length;
        dataVal.ref.mv_data = valuePtr.cast();

        final result = _lib.mdb_put(
          txn,
          dbi,
          keyVal,
          dataVal,
          0,
        );

        if (result != 0) {
          throw LMDBException('Failed to put data', result);
        }
      } finally {
        calloc.free(keyVal);
        calloc.free(dataVal);
      }
    } finally {
      calloc.free(keyPtr);
      calloc.free(valuePtr);
    }
  }

  Future<List<int>?> get(Pointer<MDB_txn> txn, String key) async {
    final dbi = await _openDatabase(txn);
    final keyPtr = key.toNativeUtf8();

    try {
      final keyVal = calloc<MDB_val>();
      final dataVal = calloc<MDB_val>();

      try {
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
        } else if (result == -30798) {
          // MDB_NOTFOUND
          return null;
        } else {
          throw LMDBException('Failed to get data', result);
        }
      } finally {
        calloc.free(keyVal);
        calloc.free(dataVal);
      }
    } finally {
      calloc.free(keyPtr);
    }
  }

  Future<DatabaseStats> stats(Pointer<MDB_txn> txn) async {
    final dbi = await _openDatabase(txn);
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

  // Auto-transaction operations
  Future<void> putAuto(String key, List<int> value) async {
    final txn = await txnStart();
    try {
      await put(txn, key, value);
      await txnCommit(txn);
    } catch (e) {
      await txnAbort(txn);
      rethrow;
    }
  }

  Future<List<int>?> getAuto(String key) async {
    final txn = await txnStart();
    try {
      final result = await get(txn, key);
      await txnCommit(txn);
      return result;
    } catch (e) {
      await txnAbort(txn);
      rethrow;
    }
  }

  Future<DatabaseStats> statsAuto() async {
    final txn = await txnStart();
    try {
      final result = await stats(txn);
      await txnCommit(txn);
      return result;
    } catch (e) {
      await txnAbort(txn);
      rethrow;
    }
  }

  // Base delete operation (requires transaction)
  Future<void> delete(Pointer<MDB_txn> txn, String key) async {
    final dbi = await _openDatabase(txn);
    final keyPtr = key.toNativeUtf8();

    try {
      final keyVal = calloc<MDB_val>();
      try {
        keyVal.ref.mv_size = keyPtr.length;
        keyVal.ref.mv_data = keyPtr.cast();

        final result = _lib.mdb_del(
          txn,
          dbi,
          keyVal,
          nullptr,
        );

        if (result != 0 && result != -30798) {
          // Ignore MDB_NOTFOUND
          throw LMDBException('Failed to delete data', result);
        }
      } finally {
        calloc.free(keyVal);
      }
    } finally {
      calloc.free(keyPtr);
    }
  }

  // Auto-transaction version of delete
  Future<void> deleteAuto(String key) async {
    final txn = await txnStart();
    try {
      await delete(txn, key);
      await txnCommit(txn);
    } catch (e) {
      await txnAbort(txn);
      rethrow;
    }
  }

  Future<int> _openDatabase(Pointer<MDB_txn> txn) async {
    final dbiPtr = calloc<MDB_dbi>();
    try {
      final result = _lib.mdb_dbi_open(
        txn,
        nullptr, // unnamed database
        MDB_CREATE, // flags
        dbiPtr,
      );

      if (result != 0) {
        throw LMDBException('Failed to open database', result);
      }

      return dbiPtr.value;
    } finally {
      calloc.free(dbiPtr);
    }
  }

  /// Gets the version of the LMDB library
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

  /// Gets an error string for the given error code
  String getErrorString(int err) {
    final ptr = _lib.mdb_strerror(err);
    return ptr.cast<Utf8>().toDartString();
  }

  /// Closes the database environment and releases all resources
  void close() {
    _lib.mdb_env_close(_env);
  }

  /// Synchronizes the environment to disk
  Future<void> sync(bool force) async {
    final result = _lib.mdb_env_sync(_env, force ? 1 : 0);
    if (result != 0) {
      throw LMDBException('Failed to sync environment', result);
    }
  }

  Future<DatabaseStats> getStats() async {
    late final Pointer<MDB_txn> txn;
    try {
      // Starte Transaktion (read-only)
      final txnPtr = calloc<Pointer<MDB_txn>>();
      try {
        final result = _lib.mdb_txn_begin(
          _env,
          nullptr,
          MDB_RDONLY, // Read-only flag hinzufügen
          txnPtr,
        );

        if (result != 0) {
          throw LMDBException('Failed to start transaction', result);
        }
        txn = txnPtr.value;
      } finally {
        calloc.free(txnPtr);
      }

      // Öffne Datenbank
      final dbiPtr = calloc<MDB_dbi>();
      late final int dbi;
      try {
        final result = _lib.mdb_dbi_open(
          txn,
          nullptr,
          0, // Keine CREATE-Flag für read-only
          dbiPtr,
        );

        if (result != 0) {
          throw LMDBException('Failed to open database', result);
        }
        dbi = dbiPtr.value;
      } finally {
        calloc.free(dbiPtr);
      }

      // Hole Statistiken
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
    } finally {
      _lib.mdb_txn_abort(txn);
    }
  }
}
