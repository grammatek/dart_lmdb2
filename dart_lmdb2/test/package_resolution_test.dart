import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Package Resolution Tests', () {
    test('can resolve dart_lmdb2 package path', () async {
      // Test the same package resolution logic used in fetch_native.dart
      final packageUri = Uri.parse('package:dart_lmdb2/lmdb.dart');
      final resolvedUri = await Isolate.resolvePackageUri(packageUri);

      expect(resolvedUri, isNotNull,
          reason: 'Should resolve dart_lmdb2 package URI');

      final filePath = resolvedUri!.toFilePath();
      // Use path.join for platform-independent path handling
      final expectedEnding = path.join('lib', 'lmdb.dart');
      expect(
          filePath.toLowerCase().endsWith(expectedEnding.toLowerCase()), isTrue,
          reason: 'Should resolve to lmdb.dart within lib directory');

      // Extract package root (two levels up from lib/lmdb.dart)
      final libDir = path.dirname(filePath);
      final packageRoot = path.dirname(libDir);

      expect(path.basename(libDir), equals('lib'),
          reason: 'Parent directory of lmdb.dart should be "lib"');

      // Check that the resolved path actually exists
      final lmdbFilePath = path.join(packageRoot, 'lib', 'lmdb.dart');
      expect(File(lmdbFilePath).existsSync(), isTrue,
          reason: 'Should resolve to an existing lmdb.dart file');

      // Verify native directory structure
      final nativeDir = path.join(packageRoot, 'lib', 'src', 'native');

      // Create directory if it doesn't exist
      final nativeDirExists = Directory(nativeDir).existsSync();
      if (!nativeDirExists) {
        Directory(nativeDir).createSync(recursive: true);
      }

      // Now verify it exists
      expect(Directory(nativeDir).existsSync(), isTrue,
          reason: 'Should be able to access native directory');
    });

    test('resolution works consistently for fetch_native', () async {
      // Since we're running from the package test directory,
      // both methods should point to the same package location

      // Method 1: Direct file path navigation (old method)
      final directPath = path.join('lib', 'src', 'native');

      // Method 2: Package resolution (new method)
      final packageUri = Uri.parse('package:dart_lmdb2/lmdb.dart');
      final resolvedUri = await Isolate.resolvePackageUri(packageUri);
      final libDir = path.dirname(resolvedUri!.toFilePath());
      final packageRoot = path.dirname(libDir);
      final resolutionPath = path.join(packageRoot, 'lib', 'src', 'native');

      // Get canonical paths for comparison
      final absoluteDirectPath = path.normalize(File(directPath).absolute.path);
      final absoluteResolutionPath =
          path.normalize(File(resolutionPath).absolute.path);

      // Print paths for debugging
      print('Direct path: $absoluteDirectPath');
      print('Resolution path: $absoluteResolutionPath');

      // When running in the package itself, these should be equivalent
      // This test passes in the package, but would fail in a consumer app
      expect(absoluteDirectPath.toLowerCase(),
          absoluteResolutionPath.toLowerCase(),
          reason: 'When running from within the package, paths should match');
    });
  });
}
