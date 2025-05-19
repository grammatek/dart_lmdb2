import 'package:test/test.dart';
import 'package:dart_lmdb2/src/version.dart';
import 'package:dart_lmdb2/src/fetch_native.dart';

void main() {
  group('Version Integration Tests', () {
    test('detectVersion returns embedded version for dart_lmdb2', () async {
      final detectedVersion = await detectVersion();

      expect(detectedVersion, equals(dartLmdb2Version),
          reason:
              'detectVersion should return the embedded version for dart_lmdb2');
    });

    test('detectPackageName identifies dart_lmdb2 correctly', () async {
      final packageName = await detectPackageName();

      expect(packageName, equals('dart_lmdb2'),
          reason: 'Should correctly identify package as dart_lmdb2');
    });

    test('version is used correctly in fetch_native flow', () async {
      // This tests that the version can be properly used in the fetch flow
      final version = await detectVersion();

      // Verify version format is correct for GitHub release tags
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')),
          reason: 'Version should be in semver format for GitHub releases');

      // Test that version would create valid tag name
      final expectedTag = 'dart_lmdb2_v$version';
      expect(expectedTag, matches(RegExp(r'^dart_lmdb2_v\d+\.\d+\.\d+')),
          reason: 'Should create valid GitHub release tag');
    });

    test('version detection handles consumer packages correctly', () async {
      // This is more of a documentation test showing how version detection works
      final version = await detectVersion();

      // In dart_lmdb2, it should always use embedded version
      expect(version, equals(dartLmdb2Version));

      // Document expected behavior for other scenarios:
      // - flutter_lmdb2: reads dart_lmdb2 version from dependencies
      // - consumer packages: falls back to embedded version
      // - no pubspec.yaml: uses embedded version
    });
  });
}
