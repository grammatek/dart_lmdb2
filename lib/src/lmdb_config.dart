import 'database_stats.dart';

class LMDBConfig {
  /// Default page size in bytes
  static const int defaultPageSize = 16384; // 16KB

  /// Default overhead factor for B+-tree and fragmentation
  static const double defaultOverheadFactor = 1.5;

  /// Minimum map size in bytes
  static const int minMapSize = 10485760; // 10MB

  /// Calculates the recommended map size based on expected data characteristics
  static int calculateMapSize({
    required int expectedEntries,
    required int averageKeySize,
    required int averageValueSize,
    double overheadFactor = defaultOverheadFactor,
    int minimumSize = minMapSize,
  }) {
    final dataSize = (averageKeySize + averageValueSize) * expectedEntries;
    final estimatedSize = (dataSize * overheadFactor).ceil();

    // Round up to next page size
    final pages = (estimatedSize / defaultPageSize).ceil();
    final alignedSize = pages * defaultPageSize;

    return alignedSize < minimumSize ? minimumSize : alignedSize;
  }

  /// Calculates the maximum number of possible entries for a given map size
  static int calculateMaxEntries({
    required int mapSize,
    required int averageKeySize,
    required int averageValueSize,
    double overheadFactor = defaultOverheadFactor,
  }) {
    final entrySize = averageKeySize + averageValueSize;
    return (mapSize / (entrySize * overheadFactor)).floor();
  }

  /// Analyzes current database usage
  static String analyzeUsage(DatabaseStats stats) {
    final totalPages =
        stats.leafPages + stats.branchPages + stats.overflowPages;
    final usedSpace = totalPages * stats.pageSize;
    final averageEntriesPerPage = stats.entries / stats.leafPages;

    return '''
Database Usage Analysis:
- Total Entries: ${stats.entries}
- Tree Depth: ${stats.depth}
- Page Size: ${stats.pageSize} bytes
- Total Pages: $totalPages
- Used Space: ${(usedSpace / 1024 / 1024).toStringAsFixed(2)} MB
- Average Entries per Leaf Page: ${averageEntriesPerPage.toStringAsFixed(2)}
- Branch/Leaf Ratio: ${(stats.branchPages / stats.leafPages).toStringAsFixed(3)}
''';
  }
}

// Configuration class for database initialization
class LMDBInitConfig {
  /// Maximum database size in bytes
  final int mapSize;

  /// Maximum number of named databases
  final int maxDbs;

  /// Environment flags
  final int envFlags;

  /// File permissions (Unix)
  final int mode;

  const LMDBInitConfig({
    required this.mapSize,
    this.maxDbs = 1,
    this.envFlags = 0,
    this.mode = 0664,
  });

  /// Creates a configuration based on expected data characteristics
  factory LMDBInitConfig.fromEstimate({
    required int expectedEntries,
    required int averageKeySize,
    required int averageValueSize,
    double overheadFactor = LMDBConfig.defaultOverheadFactor,
    int maxDbs = 1,
    int envFlags = 0,
    int mode = 0664,
  }) {
    final mapSize = LMDBConfig.calculateMapSize(
      expectedEntries: expectedEntries,
      averageKeySize: averageKeySize,
      averageValueSize: averageValueSize,
      overheadFactor: overheadFactor,
    );

    return LMDBInitConfig(
      mapSize: mapSize,
      maxDbs: maxDbs,
      envFlags: envFlags,
      mode: mode,
    );
  }
}
