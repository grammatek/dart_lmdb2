import 'generated_bindings.dart';

/// A class for managing LMDB flag combinations in a type-safe way.
///
/// This class provides methods to combine, check and manipulate LMDB flags
/// that control various aspects of database behavior. It handles the bitwise
/// operations internally and provides a clean interface for Dart code.
///
/// Example:
/// ```dart
/// // Create a custom flag set
/// final flags = LMDBFlagSet()
///   ..add(MDB_NOSUBDIR)
///   ..add(MDB_NOSYNC);
///
/// // Or use predefined combinations
/// final readOnlyFlags = LMDBFlagSet.readOnly;
/// ```
class LMDBFlagSet {
  /// Internal storage for the combined flags
  int _flags = 0;

  /// Creates an empty flag set with no flags set.
  LMDBFlagSet();

  /// Creates a flag set initialized with the provided flags value.
  ///
  /// This constructor is useful when you already have a combined flags value
  /// from native LMDB calls.
  ///
  /// [_flags] The pre-combined flags value to initialize with.
  LMDBFlagSet.fromFlags(this._flags);

  /// Adds a flag to the set using bitwise OR operation.
  ///
  /// [flag] The LMDB flag to add (e.g., MDB_RDONLY, MDB_NOSUBDIR).
  void add(int flag) => _flags |= flag;

  /// Removes a flag from the set using bitwise operations.
  ///
  /// [flag] The LMDB flag to remove from the set.
  void remove(int flag) => _flags &= ~flag;

  /// Checks if a specific flag is set in this flag set.
  ///
  /// [flag] The LMDB flag to check for.
  ///
  /// Returns true if the flag is set, false otherwise.
  bool contains(int flag) => (_flags & flag) == flag;

  /// Gets the combined value of all flags in this set.
  ///
  /// This value can be directly used in LMDB API calls.
  ///
  /// Returns the integer representation of the combined flags.
  int get value => _flags;

  /// Creates a flag set for read-only database access.
  ///
  /// This combination uses MDB_RDONLY for read-only access and MDB_NOTLS
  /// for better thread handling. This is suitable for scenarios where
  /// multiple readers need to access the database simultaneously without
  /// any write operations.
  ///
  /// Important: Read the LMDB documentation thoroughly before using this
  /// flag combination in production.
  static LMDBFlagSet get readOnly => LMDBFlagSet()
    ..add(MDB_RDONLY)
    ..add(MDB_NOTLS);

  /// Creates a flag set for read-only access to a database file in an
  /// unwritable directory.
  ///
  /// This combination is particularly useful when accessing a database
  /// from an asset directory or other read-only location. It combines:
  /// - MDB_RDONLY: For read-only access
  /// - MDB_NOSUBDIR: Treat the path as the database file itself
  /// - MDB_NOLOCK: Don't lock the database file
  ///
  /// This is commonly used in mobile applications where the database
  /// might be bundled with the application in a read-only location.
  static LMDBFlagSet get readOnlyFromAssets => LMDBFlagSet()
    ..add(MDB_RDONLY)
    ..add(MDB_NOSUBDIR)
    ..add(MDB_NOLOCK);

  /// Creates a flag set optimized for high performance operations.
  ///
  /// WARNING: This flag combination prioritizes performance over durability.
  /// It provides ACI (Atomicity, Consistency, Isolation) guarantees but NOT
  /// Durability. This means that the most recent transactions might be lost
  /// in case of a system crash.
  ///
  /// The combination includes:
  /// - MDB_WRITEMAP: Use writeable memory map
  /// - MDB_MAPASYNC: Flush asynchronously
  /// - MDB_NOSYNC: Don't flush system buffers
  ///
  /// IMPORTANT: Thoroughly understand the implications and read the LMDB
  /// documentation before using this in production environments.
  static LMDBFlagSet get highPerformance => LMDBFlagSet()
    ..add(MDB_WRITEMAP)
    ..add(MDB_MAPASYNC)
    ..add(MDB_NOSYNC);

  /// Creates a flag set with default settings.
  ///
  /// This provides the most basic and safe configuration with no special
  /// flags set. It's suitable for general-purpose use where you don't
  /// need specific optimizations or behavior modifications.
  static LMDBFlagSet get defaultFlags => LMDBFlagSet();
}
