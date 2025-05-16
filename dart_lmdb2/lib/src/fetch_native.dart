import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// Downloads native libraries from GitHub releases with manifest support
Future<void> fetchNativeLibraries({String? targetDir}) async {
  final version = await detectVersion();
  final packageName = await detectPackageName();

  print('Fetching native libraries for $packageName v$version...');

  // Check if libraries already exist with correct version
  final nativePath = targetDir ?? path.join('lib', 'src', 'native');
  if (await checkVersionMatch(nativePath, version)) {
    print('Native libraries are up to date (v$version).');
    return;
  }

  // Construct the tag name and asset name
  // Always download from dart_lmdb2 releases, even if called from flutter_lmdb2
  final tagName = 'dart_lmdb2_v$version';
  final assetName = 'dart_lmdb2-$version-native-libs.tar.gz';

  // Download the tarball
  final tarballPath = path.join(Directory.systemTemp.path, assetName);
  await downloadReleaseTarball('dart_lmdb2', version, tagName, tarballPath);

  // Extract to target directory
  await extractTarball(tarballPath, nativePath);

  // Clean up
  File(tarballPath).deleteSync();

  print('Native libraries successfully downloaded and extracted!');
}

/// Detects the current package name from pubspec.yaml
Future<String> detectPackageName() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw Exception('pubspec.yaml not found');
  }

  final pubspecContent = await pubspecFile.readAsString();
  final pubspec = loadYaml(pubspecContent);
  return pubspec['name'];
}

/// Detects the version of dart_lmdb2 to use
Future<String> detectVersion() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw Exception('pubspec.yaml not found');
  }

  final pubspecContent = await pubspecFile.readAsString();
  final pubspec = loadYaml(pubspecContent);
  final packageName = pubspec['name'];

  // If we're in dart_lmdb2, use its version
  if (packageName == 'dart_lmdb2') {
    return pubspec['version'];
  }

  // If we're in flutter_lmdb2, get dart_lmdb2 dependency version
  if (packageName == 'flutter_lmdb2') {
    final dependencies = pubspec['dependencies'];
    if (dependencies != null && dependencies['dart_lmdb2'] != null) {
      final dep = dependencies['dart_lmdb2'];
      if (dep is String) {
        // Remove version constraint symbols
        return dep
            .replaceAll('^', '')
            .replaceAll('~', '')
            .replaceAll('>=', '')
            .trim();
      } else if (dep is Map && dep['version'] != null) {
        return dep['version'].toString();
      }
    }
    throw Exception(
        'Could not determine dart_lmdb2 version from flutter_lmdb2');
  }

  throw Exception('This script only works with dart_lmdb2 or flutter_lmdb2');
}

/// Checks if the native libraries match the expected version
Future<bool> checkVersionMatch(
    String nativePath, String expectedVersion) async {
  final manifestFile = File(path.join(nativePath, 'manifest.json'));

  if (!manifestFile.existsSync()) {
    return false; // No manifest means no libraries or old format
  }

  try {
    final manifestContent = await manifestFile.readAsString();
    final manifest = jsonDecode(manifestContent);
    return manifest['version'] == expectedVersion;
  } catch (e) {
    print('Warning: Could not read manifest.json: $e');
    return false;
  }
}

/// Download release tarball from GitHub
Future<void> downloadReleaseTarball(String packageName, String packageVersion,
    String tagName, String outputPath) async {
  final owner = 'grammatek';
  final repo = 'dart_lmdb2';
  final assetName = '$packageName-$packageVersion-native-libs.tar.gz';

  // Use HTTP API
  print('Downloading release asset from GitHub...');
  final url =
      'https://github.com/$owner/$repo/releases/download/$tagName/$assetName';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Failed to download tarball: HTTP ${response.statusCode}');
  }

  await File(outputPath).writeAsBytes(response.bodyBytes);
  print('Downloaded $assetName');
}

/// Extract tarball to target directory
Future<void> extractTarball(String tarballPath, String targetDir) async {
  // Ensure target directory exists
  Directory(targetDir).createSync(recursive: true);

  // Use dart:archive
  print('Extracting native libraries...');
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

  print('Extraction complete');
}
