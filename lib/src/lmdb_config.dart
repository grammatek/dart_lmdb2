import 'dart:math';

import 'database_stats.dart';

class LMDBConfig {
  /// Default overhead factor for B+ tree structure and future growth
  static const double defaultOverheadFactor = 1.5;

  /// Minimum map size (10MB)
  static const int minMapSize = 10 * 1024 * 1024;

  /// Calculates the maximum number of entries possible for a given map size
  ///
  /// Parameters:
  /// - mapSize: Total database size in bytes
  /// - averageKeySize: Expected average size of keys in bytes
  /// - averageValueSize: Expected average size of values in bytes
  /// - overheadFactor: Factor to account for B+ tree overhead (default: 1.5)
  ///
  /// Returns the estimated maximum number of entries that can be stored
  static int calculateMaxEntries({
    required int mapSize,
    required int averageKeySize,
    required int averageValueSize,
    double overheadFactor = defaultOverheadFactor,
  }) {
    // Calculate average entry size including overhead
    final entrySize = (averageKeySize + averageValueSize) * overheadFactor;

    // Calculate maximum entries, ensuring we don't exceed available space
    return (mapSize / entrySize).floor();
  }

  /// Calculates required map size based on expected data volume
  ///
  /// Parameters:
  /// - expectedEntries: Number of entries planned to store
  /// - averageKeySize: Expected average size of keys in bytes
  /// - averageValueSize: Expected average size of values in bytes
  /// - overheadFactor: Factor to account for B+ tree overhead (default: 1.5)
  ///
  /// Returns the recommended map size in bytes, never less than minMapSize
  static int calculateMapSize({
    required int expectedEntries,
    required int averageKeySize,
    required int averageValueSize,
    double overheadFactor = defaultOverheadFactor,
  }) {
    // Calculate raw data size
    final dataSize = (averageKeySize + averageValueSize) * expectedEntries;

    // Add overhead for B+ tree structure
    final estimatedSize = (dataSize * overheadFactor).ceil();

    // Ensure we never return less than minimum map size
    return estimatedSize < minMapSize ? minMapSize : estimatedSize;
  }

  /// Analyzes current database usage
  static String analyzeUsage(DatabaseStats stats) {
    final branchToLeafRatio =
        stats.leafPages > 0 ? stats.branchPages / stats.leafPages : 0.0;

    final averageEntriesPerLeafPage =
        stats.leafPages > 0 ? stats.entries / stats.leafPages : 0.0;

    return '''
Database Usage Analysis:
- Total Entries: ${stats.entries}
- Tree Structure:
  • Depth: ${stats.depth}
  • Branch Pages: ${stats.branchPages}
  • Leaf Pages: ${stats.leafPages}
  • Branch/Leaf Ratio: ${branchToLeafRatio.toStringAsFixed(3)}
- Performance Metrics:
  • Average Entries per Leaf Page: ${averageEntriesPerLeafPage.toStringAsFixed(2)}
  • Overflow Pages: ${stats.overflowPages}
''';
  }

  /// Analyzes database efficiency and returns structured metrics
  static DatabaseEfficiency analyzeEfficiency(DatabaseStats stats) {
    return DatabaseEfficiency(
      totalEntries: stats.entries,
      treeDepth: stats.depth,
      branchToLeafRatio:
          stats.leafPages > 0 ? stats.branchPages / stats.leafPages : 0.0,
      averageEntriesPerLeafPage:
          stats.leafPages > 0 ? stats.entries / stats.leafPages : 0.0,
      hasOverflow: stats.overflowPages > 0,
    );
  }
}

// Represents database efficiency metrics for analyzing LMDB performance
class DatabaseEfficiency {
  final int totalEntries;
  final int treeDepth;
  final double branchToLeafRatio;
  final double averageEntriesPerLeafPage;
  final bool hasOverflow;

  DatabaseEfficiency({
    required this.totalEntries,
    required this.treeDepth,
    required this.branchToLeafRatio,
    required this.averageEntriesPerLeafPage,
    required this.hasOverflow,
  });

  /// Returns true if the B+ tree structure is well-balanced
  /// A well-balanced tree has:
  /// - Branch to leaf ratio < 0.3 (fewer branch pages than leaf pages)
  /// - Tree depth close to optimal for the number of entries
  bool get isWellBalanced =>
      branchToLeafRatio < 0.3 &&
      treeDepth <= (log(totalEntries) / log(2)).ceil();

  /// Returns true if the database storage is efficiently utilized
  /// Efficient storage has:
  /// - Good number of entries per leaf page
  /// - No overflow pages
  bool get isEfficient => averageEntriesPerLeafPage > 10 && !hasOverflow;
}

/// convert octal String into integer
int parseOctalString(String octalStr) {
  // remove any leading zeros or '0o'
  octalStr = octalStr.replaceFirst(RegExp(r'^[0o]+'), '');

  int result = 0;
  for (int i = 0; i < octalStr.length; i++) {
    int digit = int.parse(octalStr[i]);
    if (digit >= 8) {
      throw FormatException('invalid octal number given: $digit in $octalStr');
    }
    result = result * 8 + digit;
  }
  return result;
}

// Configuration class for database initialization
class LMDBInitConfig {
  /// Maximum database size in bytes
  final int mapSize;

  /// Maximum number of named databases
  final int maxDbs;

  /// File permissions (Unix)
  final String mode;

  int get modeAsInt => parseOctalString(mode);

  const LMDBInitConfig({
    required this.mapSize,
    this.maxDbs = 1,
    this.mode = "644",
  });

  /// Creates a configuration based on expected data characteristics
  factory LMDBInitConfig.fromEstimate({
    required int expectedEntries,
    required int averageKeySize,
    required int averageValueSize,
    double overheadFactor = LMDBConfig.defaultOverheadFactor,
    int maxDbs = 1,
    int mode = 438, // 438 decimal == 644 octal
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
      mode: mode.toRadixString(8),
    );
  }
}
