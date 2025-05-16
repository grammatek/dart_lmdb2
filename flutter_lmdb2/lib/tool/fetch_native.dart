import 'package:dart_lmdb2/lmdb.dart' as dart_lmdb2;

/// Downloads native libraries from dart_lmdb2 GitHub releases
Future<void> fetchNativeLibs() async {
  try {
    // Use dart_lmdb2's fetch functionality, targeting flutter_lmdb2's native directory
    await dart_lmdb2.fetchNativeLibraries(targetDir: 'lib/src/native');
  } catch (e) {
    print('Error fetching native libraries: $e');
    rethrow;
  }
}
