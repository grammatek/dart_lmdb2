#!/usr/bin/env dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// Release script for dart_lmdb2 and flutter_lmdb2 packages
///
/// This script automates steps 4 and 5 of the release process:
/// - Downloads the native libraries tarball from GitHub releases
/// - Extracts the tarball to the correct location
/// - Publishes the package to pub.dev
///
/// Usage:
///   dart run tool/release.dart --package=dart_lmdb2
///   dart run tool/release.dart --package=flutter_lmdb2
///
/// Options:
///   --package   Package to release (dart_lmdb2 or flutter_lmdb2)
///   --tag       Specific tag to use (defaults to latest matching tag)
///   --no-pub    Skip publishing to pub.dev (extract libraries only)
///   --help      Show this help message

Future<void> main(List<String> args) async {
  // Parse arguments
  final arguments = parseArgs(args);
  if (arguments['help'] == true) {
    printUsage();
    exit(0);
  }

  final String? packageName = arguments['package'];
  if (packageName == null ||
      (packageName != 'dart_lmdb2' && packageName != 'flutter_lmdb2')) {
    print(
        'Error: You must specify a valid package name (dart_lmdb2 or flutter_lmdb2)');
    printUsage();
    exit(1);
  }

  // Get repo directory (parent of script directory)
  final scriptFile = File(Platform.script.toFilePath());
  final repoDir = scriptFile.parent.parent.absolute.path;
  final packageDir = path.join(repoDir, packageName);

  // Read package version from pubspec.yaml
  final pubspecFile = File(path.join(packageDir, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found at $packageDir');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(pubspecContent);
  final packageVersion = pubspec['version'].toString();

  print('Working with $packageName version $packageVersion');

  // Determine tag to use
  String tagName = arguments['tag'] ?? '${packageName}_v$packageVersion';
  print('Using tag: $tagName');

  // Determine version string for tarball filename
  String versionString = packageVersion;
  if (tagName.contains('_test_')) {
    // For test releases, extract version from tag
    versionString = tagName.replaceFirst('${packageName}_test_', 'test-');
  }

  // Create release build directory
  final releaseDirName = 'release_${packageName}_$versionString';
  final releaseDirPath = path.join(repoDir, releaseDirName);
  final releaseDir = Directory(releaseDirPath);
  
  // Clean up old release directory if it exists
  if (releaseDir.existsSync()) {
    print('Cleaning up existing release directory: $releaseDirPath');
    releaseDir.deleteSync(recursive: true);
  }
  releaseDir.createSync();
  print('Created release directory: $releaseDirPath');

  // Copy package to release directory
  final releasePackageDir = path.join(releaseDirPath, packageName);
  await copyDirectory(Directory(packageDir), Directory(releasePackageDir));
  print('Copied package to release directory');

  // Download release tarball
  final tarballFileName = '$packageName-$versionString-native-libs.tar.gz';
  final tarballPath = path.join(releaseDirPath, tarballFileName);
  final tarballFile = File(tarballPath);

  try {
    await downloadReleaseTarball(
        packageName, versionString, tagName, tarballPath);
    print('Downloaded $tarballFileName');
  } catch (e) {
    print('Error downloading tarball: $e');
    print(
        'Please ensure the GitHub release for $tagName exists and contains the tarball.');
    exit(1);
  }

  // Extract tarball to native directory in release folder
  final nativePath = path.join(releasePackageDir, 'lib', 'src', 'native');
  try {
    await extractTarball(tarballPath, nativePath);
    print('Extracted native libraries to $nativePath');
  } catch (e) {
    print('Error extracting tarball: $e');
    exit(1);
  }

  // Verify native libraries were extracted correctly
  final nativeDir = Directory(nativePath);
  if (!nativeDir.existsSync()) {
    print('Error: Native directory not found after extraction');
    exit(1);
  }

  print('Native libraries extracted successfully');
  print('Directory structure:');

  // List extracted files
  await listDirectory(nativeDir);

  // Clean up tarball
  tarballFile.deleteSync();

  // Publish to pub.dev
  if (arguments['no-pub'] != true) {
    final isDryRun = arguments['dry-run'] == true;
    
    if (isDryRun) {
      print('\nRunning dry-run to check if $packageName can be published...');
    } else {
      print('\nPublishing $packageName to pub.dev...');
    }

    final publishArgs = ['pub', 'publish'];
    if (isDryRun) {
      publishArgs.add('--dry-run');
    } else {
      publishArgs.add('--force');
    }

    Process process;
    if (packageName == 'flutter_lmdb2') {
      process = await Process.start('flutter', publishArgs,
          workingDirectory: releasePackageDir);
    } else {
      process = await Process.start('dart', publishArgs,
          workingDirectory: releasePackageDir);
    }

    // Forward output to console
    process.stdout.transform(SystemEncoding().decoder).listen(print);
    process.stderr.transform(SystemEncoding().decoder).listen(print);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      print('Error: Publishing failed with exit code $exitCode');
      exit(exitCode);
    }

    if (isDryRun) {
      print('\nDry-run completed successfully!');
      print('$packageName v$packageVersion is ready to be published.');
      print('To publish for real, run without --dry-run flag');
    } else {
      print('Successfully published $packageName v$packageVersion to pub.dev!');
    }
  } else {
    print('\nSkipping pub.dev publishing (--no-pub flag used)');
    print('Native libraries are ready for manual publishing:');
    print('  cd $releasePackageDir');
    if (packageName == 'flutter_lmdb2') {
      print('  flutter pub publish');
    } else {
      print('  dart pub publish');
    }
  }
  
  print('\nRelease build directory: $releaseDirPath');
}

/// Parse command line arguments
Map<String, dynamic> parseArgs(List<String> args) {
  final result = <String, dynamic>{};

  for (final arg in args) {
    if (arg == '--help') {
      result['help'] = true;
    } else if (arg == '--no-pub') {
      result['no-pub'] = true;
    } else if (arg == '--dry-run') {
      result['dry-run'] = true;
    } else if (arg.startsWith('--package=')) {
      result['package'] = arg.substring('--package='.length);
    } else if (arg.startsWith('--tag=')) {
      result['tag'] = arg.substring('--tag='.length);
    } else {
      print('Unknown argument: $arg');
      result['help'] = true;
    }
  }

  return result;
}

/// Print usage instructions
void printUsage() {
  print('Usage: dart run tool/release.dart [options]');
  print('');
  print('Options:');
  print('  --package=<name>  Package to release (dart_lmdb2 or flutter_lmdb2)');
  print(
      '  --tag=<tag>       Specific tag to use (defaults to latest matching tag)');
  print(
      '  --no-pub          Skip publishing to pub.dev (extract libraries only)');
  print(
      '  --dry-run         Run pub publish with --dry-run to check if package would be accepted');
  print('  --help            Show this help message');
}

/// Download release tarball from GitHub
Future<void> downloadReleaseTarball(String packageName, String packageVersion,
    String tagName, String outputPath) async {
  final owner = 'grammatek';
  final repo = 'dart_lmdb2';
  final assetName = '$packageName-$packageVersion-native-libs.tar.gz';

  // Check if GitHub CLI is available
  final ghResult = await Process.run('which', ['gh']);
  if (ghResult.exitCode == 0) {
    // Use GitHub CLI
    print('Using GitHub CLI to download release asset');
    final process = await Process.run('gh', [
      'release',
      'download',
      tagName,
      '-p',
      assetName,
      '-D',
      path.dirname(outputPath),
      '-R',
      '$owner/$repo'
    ]);

    if (process.exitCode != 0) {
      throw Exception('GitHub CLI failed: ${process.stderr}');
    }
    return;
  }

  // Fallback to HTTP API
  print('GitHub CLI not found, using HTTP API');
  final url =
      'https://github.com/$owner/$repo/releases/download/$tagName/$assetName';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Failed to download tarball: HTTP ${response.statusCode}');
  }

  await File(outputPath).writeAsBytes(response.bodyBytes);
}

/// Extract tarball to target directory
Future<void> extractTarball(String tarballPath, String targetDir) async {
  // Check if tar command is available
  final tarResult = await Process.run('which', ['tar']);
  if (tarResult.exitCode == 0) {
    // Use system tar command
    print('Using system tar command');
    final process =
        await Process.run('tar', ['-xzf', tarballPath, '-C', targetDir]);

    if (process.exitCode != 0) {
      throw Exception('Tar extraction failed: ${process.stderr}');
    }
    return;
  }

  // Fallback to dart:archive
  print('System tar not found, using Dart archive package');
  final bytes = await File(tarballPath).readAsBytes();
  final gzipDecoder = GZipDecoder();
  final tarData = gzipDecoder.decodeBytes(bytes);
  final tarArchive = TarDecoder().decodeBytes(tarData);

  for (final file in tarArchive) {
    final outputPath = path.join(targetDir, file.name);
    if (file.isFile) {
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content);
    } else {
      await Directory(outputPath).create(recursive: true);
    }
  }
}

/// Recursively list directory contents
Future<void> listDirectory(Directory dir, {String indent = ''}) async {
  final entities = await dir.list().toList();
  entities.sort((a, b) => a.path.compareTo(b.path));

  for (final entity in entities) {
    final name = path.basename(entity.path);
    if (entity is Directory) {
      print('$indent$name/');
      await listDirectory(entity, indent: '$indent  ');
    } else {
      print('$indent$name');
    }
  }
}

/// Copy directory recursively
Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }

  await for (final entity in source.list(recursive: false)) {
    if (entity is Directory) {
      final newDirectory = Directory(path.join(destination.path, path.basename(entity.path)));
      await copyDirectory(entity, newDirectory);
    } else if (entity is File) {
      final newFile = File(path.join(destination.path, path.basename(entity.path)));
      await entity.copy(newFile.path);
    }
  }
}
