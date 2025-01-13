/// Represents statistical information about an LMDB database.
///
/// This class provides detailed metrics about the database structure,
/// including page allocation and B+ tree characteristics.
class DatabaseStats {
  /// Size of a database page in bytes.
  ///
  /// This is typically a multiple of the system's page size
  /// (usually 4096 bytes on most systems).
  final int pageSize;

  /// Depth of the B+ tree.
  ///
  /// Indicates how many levels of pages must be traversed
  /// to reach any leaf page from the root.
  final int depth;

  /// Number of branch pages in the B+ tree.
  ///
  /// Branch pages contain only keys and pointers to other pages,
  /// forming the internal nodes of the tree.
  final int branchPages;

  /// Number of leaf pages in the B+ tree.
  ///
  /// Leaf pages contain the actual key-value pairs
  /// stored in the database.
  final int leafPages;

  /// Number of overflow pages.
  ///
  /// Overflow pages are used when values are too large
  /// to fit in a regular leaf page.
  final int overflowPages;

  /// Total number of entries (key-value pairs) in the database.
  final int entries;

  /// Creates a new DatabaseStats instance.
  ///
  /// Example:
  /// ```dart
  /// final stats = DatabaseStats(
  ///   pageSize: 4096,
  ///   depth: 3,
  ///   branchPages: 10,
  ///   leafPages: 100,
  ///   overflowPages: 0,
  ///   entries: 1000,
  /// );
  /// ```
  DatabaseStats({
    required this.pageSize,
    required this.depth,
    required this.branchPages,
    required this.leafPages,
    required this.overflowPages,
    required this.entries,
  });

  /// Returns a string representation of the database statistics.
  ///
  /// Useful for logging and debugging purposes.
  ///
  /// Example:
  /// ```dart
  /// final stats = await db.getStats();
  /// print(stats.toString());
  /// // Prints: DatabaseStats(pageSize: 4096, depth: 3, ...)
  /// ```
  @override
  String toString() {
    return 'DatabaseStats('
        'pageSize: $pageSize, '
        'depth: $depth, '
        'branchPages: $branchPages, '
        'leafPages: $leafPages, '
        'overflowPages: $overflowPages, '
        'entries: $entries)';
  }
}
