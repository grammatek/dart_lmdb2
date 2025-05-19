#!/usr/bin/env dart

import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  // Read version from pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(pubspecContent);
  final pubspecVersion = pubspec['version'];

  // Read version from version.dart
  final versionFile = File('lib/src/version.dart');
  if (!versionFile.existsSync()) {
    print('Error: lib/src/version.dart not found');
    print('Run tool/install-hooks.sh to set up git hooks');
    exit(1);
  }

  final versionContent = versionFile.readAsStringSync();
  final versionMatch = RegExp(r"const String dartLmdb2Version = '(.+)';").firstMatch(versionContent);

  if (versionMatch == null) {
    print('Error: Could not parse version from version.dart');
    exit(1);
  }

  final versionDartVersion = versionMatch.group(1);

  // Compare versions
  if (pubspecVersion != versionDartVersion) {
    print('Version mismatch!');
    print('  pubspec.yaml: $pubspecVersion');
    print('  version.dart: $versionDartVersion');
    print('');
    print('To fix: make a git commit or run the pre-commit hook manually:');
    print('  .git/hooks/pre-commit');
    exit(1);
  }

  print('Version verification passed: $pubspecVersion');
}