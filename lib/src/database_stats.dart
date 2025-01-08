class DatabaseStats {
  final int pageSize;
  final int depth;
  final int branchPages;
  final int leafPages;
  final int overflowPages;
  final int entries;

  DatabaseStats({
    required this.pageSize,
    required this.depth,
    required this.branchPages,
    required this.leafPages,
    required this.overflowPages,
    required this.entries,
  });

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
