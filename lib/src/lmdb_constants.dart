import 'generated_bindings.dart' as bindings;

/// Opens the environment in read-only mode.
///
/// When used:
/// - All write operations will be prohibited
/// - Multiple processes can access database simultaneously
/// - Perfect for read-only scenarios like dictionaries or lookups
///
/// Common usage scenarios:
/// - Deployment of read-only databases
/// - Concurrent access by multiple processes
/// - When using smaller mapsize than actual database size
///
/// Example:
/// ```dart
///     await db.init(path,
///         flags: LMDBFlagSet()..add(MDB_RDONLY));
/// ````
///
/// Related flags:
/// - Often used with [MDB_NOLOCK] for better read performance
/// - Compatible with [MDB_NOTLS] for multi-threaded access
const MDB_RDONLY = bindings.MDB_RDONLY;

/// Opens a database file directly instead of using a directory.
///
/// When used:
/// - Database exists as single file rather than directory
/// - Path parameter points directly to database file
/// - Simplifies deployment and file management
///
/// Common usage scenarios:
/// - Embedded applications (e.g. bundleed assets in mobile apps)
/// - Simple deployments
/// - Single-file distribution
///
/// Example:
/// ```dart
///     await db.init("mydb.lmdb",
///         flags: LMDBFlagSet()..add(MDB_NOSUBDIR));
/// ```
/// Considerations:
/// - use in combination with [MDB_RDONLY] and [MDB_NOLOCK] for read-only access
/// - Less flexible than directory-based setup
/// - Must be specified during initial creation
/// - All processes must use same flag
const MDB_NOSUBDIR = bindings.MDB_NOSUBDIR;

/// Disable syncing of system buffers to disk on transaction commit.
///
/// When used:
/// - Significantly improves write performance
/// - Increases risk of database corruption on system crash
/// - System crash might lose last transactions
///
/// Common usage scenarios:
/// - High-performance logging
/// - Temporary data storage
/// - When data loss is acceptable
///
/// Example:
/// ```dart
///     await db.init(path,
///         flags: LMDBFlagSet()..add(MDB_NOSYNC));
/// ````
///
/// Warning:
/// - Don't use when data integrity is critical
/// - System crashes can corrupt database
/// - Consider [MDB_NOMETASYNC] for safer alternative
const MDB_NOSYNC = bindings.MDB_NOSYNC;

/// Don't sync meta pages when committing transaction.
///
/// When used:
/// - Provides middle ground between sync and async commits
/// - Still flushes file system buffers
/// - Better performance than full sync
///
/// Common usage scenarios:
/// - Production systems needing balance of safety/speed
/// - When full [MDB_NOSYNC] is too risky
/// - High-performance requirements with some safety
///
/// Example:
/// ```dart
///     await db.init(path,
///         flags: LMDBFlagSet()..add(MDB_NOMETASYNC));
/// ````
///
/// Comparison:
/// - Safer than [MDB_NOSYNC]
/// - Slower than [MDB_NOSYNC]
/// - Faster than default sync behavior
const MDB_NOMETASYNC = bindings.MDB_NOMETASYNC;

/// Use a writeable memory map instead of malloc/msync for database operations.
///
/// When used:
/// - Provides faster database operations
/// - Increases vulnerability to system crashes
/// - Maps data directly into memory
///
/// Common usage scenarios:
/// - High-performance requirements
/// - Systems with reliable power/hardware
/// - When speed is priority over crash safety
///
/// Example:
/// ```dart
/// await db.init(path,
///     flags: LMDBFlagSet()..add(MDB_WRITEMAP));
/// ```
///
/// Warning:
/// - Experimental on Windows
/// - Disabled in Windows test suite
/// - Often combined with [MDB_MAPASYNC]
const MDB_WRITEMAP = bindings.MDB_WRITEMAP;

/// Enables asynchronous flushes to disk when using [MDB_WRITEMAP].
///
/// When used:
/// - Maximum write performance
/// - Highest risk of database corruption
/// - No waiting for disk writes
///
/// Common usage scenarios:
/// - Temporary data storage
/// - Performance testing
/// - When data loss is acceptable
///
/// Example:
/// ```dart
/// await db.init(path,
/// flags: LMDBFlagSet()
/// ..add(MDB_WRITEMAP)
/// ..add(MDB_MAPASYNC));
/// ````
///
/// Warning:
/// - System crashes can corrupt database
/// - Must be used with [MDB_WRITEMAP]
/// - Not suitable for critical data
const MDB_MAPASYNC = bindings.MDB_MAPASYNC;

//// Creates the named database if it doesn't exist.
///
/// When used:
/// - Automatically creates missing databases
/// - Fails if database exists
/// - Not allowed in read-only mode
///
/// Common usage scenarios:
/// - Initial database setup
/// - Dynamic database creation
/// - Application initialization
///
/// Example:
/// ```dart
/// await db.init(path,
///     flags: LMDBFlagSet()..add(MDB_CREATE));
/// ```
///
/// Restrictions:
/// - Incompatible with [MDB_RDONLY]
/// - Requires write permissions
/// - Only for new databases
const MDB_CREATE = bindings.MDB_CREATE;

/// Disables thread-local storage.
///
/// When used:
/// - Reduces per-thread memory usage
/// - Beneficial for many threads
/// - May improve performance
///
/// Common usage scenarios:
/// - Multi-threaded applications
/// - Server environments
/// - Resource-constrained systems
///
/// Example:
/// ```dart
/// await db.init(path,
/// flags: LMDBFlagSet()..add(MDB_NOTLS));
/// ```
/// Considerations:
/// - May affect thread safety
/// - Requires careful transaction handling
/// - Consider when many threads access same environment
const MDB_NOTLS = bindings.MDB_NOTLS;

// Disables locking for read-only access.
///
/// When used:
/// - Improves read-only performance
/// - Removes file locking overhead
/// - Must be used with [MDB_RDONLY]
///
/// Common usage scenarios:
/// - Single-process read-only access
/// - Performance-critical lookups
/// - Controlled environment access
///
/// Example:
/// ```dart
/// await db.init(path,
///     flags: LMDBFlagSet()
///       ..add(MDB_RDONLY)
///       ..add(MDB_NOLOCK));
/// ```
/// Warning:
/// - Requires careful multi-process coordination
/// - Can cause issues if write access occurs
/// - Only safe with [MDB_RDONLY]
const MDB_NOLOCK = bindings.MDB_NOLOCK;

/// Skips initialization of malloc'd memory before writing.
///
/// When used:
/// - Improves write performance
/// - Reduces memory operations
/// - Potential security implications
///
/// Common usage scenarios:
/// - High-performance writing
/// - Trusted data sources
/// - Controlled environments
///
/// Example:
/// ```dart
/// await db.init(path,
///     flags: LMDBFlagSet()..add(MDB_NOMEMINIT));`
/// ````
///
/// Warning:
/// - Can expose previous memory contents
/// - May cause issues with garbage data
/// - Use with caution in secure environments
const MDB_NOMEMINIT = bindings.MDB_NOMEMINIT;

/// Disables read-ahead for random access patterns.
///
/// When used:
/// - Optimizes random access patterns
/// - Reduces unnecessary I/O
/// - Helpful for large databases
///
/// Common usage scenarios:
/// - Random key lookups
/// - Databases larger than RAM
/// - SSD storage systems
///
/// Example:
/// ```dart
/// await db.init(path,
///     flags: LMDBFlagSet()..add(MDB_NORDAHEAD));`
/// ````
///
/// Benefits:
/// - Better random read performance
/// - Reduced memory usage
/// - Optimized for SSDs
const MDB_NORDAHEAD = bindings.MDB_NORDAHEAD;

/// Use fixed-size memory map.
///
/// When used:
/// - All data items must be same size
/// - Memory map size is fixed
/// - Limited flexibility
///
/// Common usage scenarios:
/// - Fixed-record databases
/// - Specialized applications
/// - Known data size patterns
///
/// Example:
/// ```dart
/// await db.init(path,
///     flags: LMDBFlagSet()..add(MDB_FIXEDMAP));`
/// ````
///
/// Limitations:
/// - All items must be same size
/// - Less flexible than dynamic mapping
/// - Specialized use cases only
const MDB_FIXEDMAP = bindings.MDB_FIXEDMAP;

/// Allows read-only access if write access is unavailable.
///
/// When used:
/// - Graceful fallback to read-only mode
/// - Handles permission restrictions
/// - Flexible access patterns
///
/// Common usage scenarios:
/// - Multi-user environments
/// - Limited permission contexts
/// - Fallback access patterns
///
/// Example:
/// ```dart
/// await db.init(path, flags: LMDBFlagSet()..add(MDB_PREVSNAPSHOT));
/// ```
///
/// Benefits:
/// - Graceful degradation
/// - Better availability
/// - Flexible deployment
const MDB_PREVSNAPSHOT = bindings.MDB_PREVSNAPSHOT;

/// Stores key/data pairs in reverse byte order.
///
/// When used:
/// - Keys are stored in reverse byte order
/// - Can improve performance for certain key types
/// - Useful for string keys with significant trailing bytes
///
/// Common usage scenarios:
/// - String-based keys
/// - Custom sorting requirements
/// - Performance optimization
///
/// Example scenario:
///
/// Normal string comparison:
/// "abc1" < "abc2" < "abd1"
///
/// With [MDB_REVERSEKEY]:
/// Internally stored and compared as:
/// "1cba" < "1dba" < "2cba"
///
/// Usage example:
/// ```dart
/// await db.init(path, flags: LMDBFlagSet()..add(MDB_REVERSEKEY));
/// await db.putUtf8(txn, "abc1", "value1");
/// await db.putUtf8(txn, "abc2", "value2");
/// await db.putUtf8(txn, "abd1", "value2");
/// ```
///
/// Performance:
/// - May improve string key handling
/// - Affects key comparison operations
/// - Consider key access patterns
const MDB_REVERSEKEY = bindings.MDB_REVERSEKEY;

/// Enables duplicate keys in the database.
///
/// When used:
/// - Multiple values per key allowed
/// - Values stored in sorted order
/// - Enables multi-value lookups
///
/// Common usage scenarios:
/// - One-to-many relationships
/// - Tag systems
/// - Multiple value storage
///
/// Example:
/// ```dart
/// await db.init(path, flags: LMDBFlagSet()..add(MDB_DUPSORT));
/// ```
///
/// Features:
/// - Automatic value sorting
/// - Compatible with [MDB_DUPFIXED]
/// - Enables cursor operations
///
/// Note:
/// - **Not yet supported as cursor operation are not yet implemented**
const MDB_DUPSORT = bindings.MDB_DUPSORT;

/// Specifies that keys are binary integers in native byte order.
///
/// When used:
/// - Keys must be fixed-size integers
/// - Native byte order comparison
/// - Optimized integer handling
///
/// Common usage scenarios:
/// - Numeric key databases
/// - Performance-critical integer keys
/// - Sequential ID systems
///
/// Example:
/// ```dart
/// await db.init(path, flags: LMDBFlagSet()..add(MDB_INTEGERKEY));
/// ```
///
/// Requirements:
/// - All keys must be same size
/// - Keys must be integers
/// - Affects key comparison behavior
const MDB_INTEGERKEY = bindings.MDB_INTEGERKEY;

/// Specifies fixed-size duplicate data items.
///
/// When used:
/// - All duplicate values must be same size
/// - Must be used with [MDB_DUPSORT]
/// - Enables optimized storage/retrieval
///
/// Common usage scenarios:
/// - Fixed-size record storage
/// - Array-like data structures
/// - Performance-critical duplicates
///
/// Example:
/// ```dart
/// await db.init(path, flags: LMDBFlagSet()..add(MDB_DUPSORT)..add(MDB_DUPFIXED));
/// ```
///
/// Requirements:
/// - All duplicate values must be same size
/// - Must be combined with [MDB_DUPSORT]
/// - Consider with [MDB_INTEGERDUP]
const MDB_DUPFIXED = bindings.MDB_DUPFIXED;

/// Enables reverse string comparison for duplicate data items.
///
/// When used:
/// - Must be used with [MDB_DUPSORT]
/// - Reverses duplicate value comparison
/// - Affects duplicate sorting order
///
/// Common usage scenarios:
/// - Custom sorting requirements
/// - Reverse chronological order
/// - Special string handling
///
/// Example:
/// ```dart
/// await db.init(path, flags: LMDBFlagSet()..add(MDB_DUPSORT)..add(MDB_REVERSEDUP));
/// ```
///
/// Note:
/// - Only affects duplicate data comparison
/// - Must be used with [MDB_DUPSORT]
/// - Doesn't affect key ordering
/// - **Not yet supported as cursor operation are not yet implemented**
const MDB_REVERSEDUP = bindings.MDB_REVERSEDUP;

/// MDB_INTEGERDUP: Used only with [MDB_DUPFIXED] databases.
/// Indicates that duplicate data items are binary integers.
/// This flag enables efficient storage and comparison of integer values similar
/// to [MDB_INTEGERKEY] for keys.
const MDB_INTEGERDUP = bindings.MDB_INTEGERDUP;

/// Flag for put operations that prevents overwriting existing keys.
///
/// When used:
/// - Put operation will fail with [MDB_KEYEXIST] if key already exists
/// - Ensures data is never accidentally overwritten
/// - Acts like an "insert-only" mode for the specific operation
///
/// Common usage scenarios:
/// - Initial data loading where duplicates should be detected
/// - Maintaining data integrity where updates are not allowed
/// - Implementing append-only patterns
///
/// Example:
/// ```dart
///     // Will fail if 'my_key' already exists
///     await db.put(txn, 'my_key', 'value',
///                 flags: LMDBFlagSet()..add(MDB_NOOVERWRITE));
/// ```
/// Related errors:
/// - Returns [MDB_KEYEXIST] when key already exists
const MDB_NOOVERWRITE = bindings.MDB_NOOVERWRITE;

//
// Error codes
//

/// MDB_SUCCESS: Operation completed successfully.
/// Return code: 0
const MDB_SUCCESS = bindings.MDB_SUCCESS;

/// MDB_MAP_RESIZED: Database was resized externally.
/// Occurs when another process has increased the database size.
/// Action required: Close and reopen the environment.
/// Common scenario: Multi-process access with dynamic growth.
const MDB_MAP_RESIZED = bindings.MDB_MAP_RESIZED;

/// MDB_MAP_FULL: Environment mapsize limit reached.
/// Occurs when:
/// - Writing would exceed the current mapsize
/// - Database has grown too large for the specified mapsize
/// Solution:
/// - Increase mapsize when opening the database
/// - Typical in write operations with insufficient initial mapsize
const MDB_MAP_FULL = bindings.MDB_MAP_FULL;

/// MDB_KEYEXIST: Key/data pair already exists.
/// Occurs during put operations when the key already exists
/// and [MDB_NOOVERWRITE] was specified.
const MDB_KEYEXIST = bindings.MDB_KEYEXIST;

/// MDB_NOTFOUND: Key/data pair not found (EOF).
/// Occurs when:
/// - Reading a non-existent key
/// - Cursor operation reaches end of data
const MDB_NOTFOUND = bindings.MDB_NOTFOUND;

/// MDB_PAGE_NOTFOUND: Requested page not found.
/// Internal error indicating database corruption
/// or invalid page access.
const MDB_PAGE_NOTFOUND = bindings.MDB_PAGE_NOTFOUND;

/// MDB_CORRUPTED: Located page was wrong type.
/// Indicates database corruption or structural integrity issues.
/// Database may need recovery or rebuilding.
const MDB_CORRUPTED = bindings.MDB_CORRUPTED;

/// MDB_PANIC: Update of meta page failed or environment had fatal error.
/// Severe error condition requiring immediate attention.
/// Database might be corrupted or system resources exhausted.
const MDB_PANIC = bindings.MDB_PANIC;

/// MDB_VERSION_MISMATCH: Environment version mismatch.
/// Occurs when:
/// - Database was created with incompatible LMDB version
/// - Attempting to open newer format with older library
const MDB_VERSION_MISMATCH = bindings.MDB_VERSION_MISMATCH;

/// MDB_INVALID: File is not an LMDB file.
/// Occurs when attempting to open a file that:
/// - Is not an LMDB database
/// - Is corrupted beyond recognition
const MDB_INVALID = bindings.MDB_INVALID;
