import 'dart:isolate';
import 'package:dart_lmdb2/lmdb.dart' as dart_lmdb2;
import 'package:path/path.dart' as path;

/// Downloads native libraries from dart_lmdb2 GitHub releases
Future<void> fetchNativeLibs() async {
  try {
    // Find the flutter_lmdb2 package directory using Isolate.resolvePackageUri
    final packageUri = Uri.parse('package:flutter_lmdb2/flutter_lmdb2.dart');
    final resolvedUri = await Isolate.resolvePackageUri(packageUri);

    if (resolvedUri == null) {
      throw Exception('Could not resolve flutter_lmdb2 package location');
    }

    // Get the package root (parent of lib directory)
    // Use path.dirname for platform-independent path handling
    final filePath = resolvedUri.toFilePath();
    final libDir = path.dirname(filePath);
    final packageRoot = path.dirname(libDir);
    final targetDir = path.join(packageRoot, 'lib', 'src', 'native');

    print('Downloading native libraries to flutter_lmdb2 at: $targetDir');

    // Use dart_lmdb2's fetch functionality with absolute path
    await dart_lmdb2.fetchNativeLibraries(targetDir: targetDir);
  } catch (e) {
    print('Error fetching native libraries: $e');
    rethrow;
  }
}
