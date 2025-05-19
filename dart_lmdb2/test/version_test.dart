import 'package:test/test.dart';
import 'package:dart_lmdb2/src/version.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';

void main() {
  group('Version Consistency Tests', () {
    test('embedded version matches pubspec.yaml', () async {
      // Read version from pubspec.yaml
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue,
          reason: 'pubspec.yaml should exist');

      final pubspecContent = await pubspecFile.readAsString();
      final pubspec = loadYaml(pubspecContent);
      final pubspecVersion = pubspec['version'];

      // Compare with embedded version
      expect(dartLmdb2Version, equals(pubspecVersion),
          reason: 'Embedded version should match pubspec.yaml version');
    });

    test('embedded version is valid semver', () {
      // Basic semver validation
      final semverPattern =
          RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z-]+)?(\+[0-9A-Za-z-]+)?$');
      expect(semverPattern.hasMatch(dartLmdb2Version), isTrue,
          reason: 'Version should be valid semver format');
    });

    test('version can be used by fetch_native', () async {
      // This is more of an integration test to ensure the version
      // is accessible and properly formatted for use in fetch_native
      expect(dartLmdb2Version, isNotEmpty);
      expect(dartLmdb2Version.contains('.'), isTrue,
          reason: 'Version should contain dots (semver format)');
    });
  });
}
