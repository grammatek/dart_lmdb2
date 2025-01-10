import 'generated_bindings.dart' as bindings;

/// Open the environment in read-only mode. No write operations will be allowed.
const MDB_RDONLY = bindings.MDB_RDONLY;

/// By default LMDB creates its environment in a directory.
/// This option allows opening a database file directly.
const MDB_NOSUBDIR = bindings.MDB_NOSUBDIR;

/// Don't flush system buffers to disk when committing a transaction.
/// This optimization means a system crash can corrupt the database or lose the last transactions.
const MDB_NOSYNC = bindings.MDB_NOSYNC;

/// Don't flush system buffers to disk when committing a transaction, but still
/// flush file system buffers. This provides a middle ground between synchronous and asynchronous commits.
const MDB_NOMETASYNC = bindings.MDB_NOMETASYNC;

/// Use a writeable memory map instead of malloc/msync. This is faster but makes the
/// system more vulnerable to crashes.
const MDB_WRITEMAP = bindings.MDB_WRITEMAP;

/// When using [MDB_WRITEMAP], use asynchronous flushes to disk.
/// This optimization means a system crash can corrupt the database.
const MDB_MAPASYNC = bindings.MDB_MAPASYNC;

/// Create the named database if it doesn't exist. This option is not allowed in read-only
/// transactions or in read-only environments.
const MDB_CREATE = bindings.MDB_CREATE;

/// Don't use thread-local storage. This can be useful when many threads are opening
/// transactions on the same environment.
const MDB_NOTLS = bindings.MDB_NOTLS;

/// Open the environment with no lock. Only has effect when used with [MDB_RDONLY].
/// This can improve read-only performance but requires care when multiple processes
/// access the database.
const MDB_NOLOCK = bindings.MDB_NOLOCK;

/// Don't initialize the malloc'd memory before writing to it.
/// This optimization can cause memory access violations if the application writes
/// data containing garbage and subsequently reads it.
const MDB_NOMEMINIT = bindings.MDB_NOMEMINIT;

/// Don't do readahead (random access is expected).
/// This can improve random read performance when the database is larger than RAM.
const MDB_NORDAHEAD = bindings.MDB_NORDAHEAD;

/// Don't initialize malloc'd memory before writing to it.
/// Only set this if every data item you store is the same size.
const MDB_FIXEDMAP = bindings.MDB_FIXEDMAP;

/// Caller is prepared for a read-only environment if a read-write environment is not available.
/// This flag is used when opening the environment.
const MDB_PREVSNAPSHOT = bindings.MDB_PREVSNAPSHOT;

/// Key/data pairs are in reverse byte order. This can improve performance when keys are
/// strings and most significant byte comes last.
const MDB_REVERSEKEY = bindings.MDB_REVERSEKEY;

/// Duplicate keys may be used in the database. (Or, from another perspective,
/// keys may have multiple data items, stored in sorted order.)
const MDB_DUPSORT = bindings.MDB_DUPSORT;

/// Keys are binary integers in native byte order. Setting this option requires all keys
/// to be the same size.
const MDB_INTEGERKEY = bindings.MDB_INTEGERKEY;

/// This is a database of integer duplicates. The data items are aligned and sorted as integers.
const MDB_DUPFIXED = bindings.MDB_DUPFIXED;

/// This flag may only be used in combination with [MDB_DUPSORT]. This option tells LMDB to
/// use reverse string comparison for the data items.
const MDB_REVERSEDUP = bindings.MDB_REVERSEDUP;

/// Only for [MDB_DUPFIXED] databases. Duplicate data items are binary integers.
const MDB_INTEGERDUP = bindings.MDB_INTEGERDUP;
