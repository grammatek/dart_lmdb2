import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'version.dart';

/// Downloads native libraries from GitHub releases with manifest support
Future<void> fetchNativeLibraries({String? targetDir}) async {
  final version = await detectVersion();
  final packageName = await detectPackageName();

  // Determine the target directory (where we'll download the libraries)
  String nativePath;

  if (targetDir != null) {
    // If a specific target directory is provided, use it (e.g., from flutter_lmdb2)
    nativePath = targetDir;
  } else {
    // No target provided - we need to determine the dart_lmdb2 package directory
    // Use package URI resolution to find the dart_lmdb2 package location
    try {
      final packageUri = Uri.parse('package:dart_lmdb2/lmdb.dart');
      final resolvedUri = await Isolate.resolvePackageUri(packageUri);

      if (resolvedUri == null) {
        throw Exception('Could not resolve dart_lmdb2 package location');
      }

      // Get the package root (two levels up from lib/lmdb.dart)
      // Use path.dirname for platform-independent path handling
      final libDir = path.dirname(resolvedUri.toFilePath());
      final packageRoot = path.dirname(libDir);
      nativePath = path.join(packageRoot, 'lib', 'src', 'native');

      print('Resolved dart_lmdb2 package at: $packageRoot');
    } catch (e) {
      // Fallback to current directory if package resolution fails
      print('Warning: Could not resolve package path: $e');
      print('Falling back to local directory');
      nativePath = path.join('lib', 'src', 'native');
    }
  }

  print('Fetching native libraries for $packageName v$version...');
  print('Target directory: $nativePath');

  // Check if libraries already exist with correct version
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

  // Verify checksums
  await verifyChecksums(nativePath);

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
    // If running as consumer and pubspec.yaml not found, use embedded version
    return dartLmdb2Version;
  }

  final pubspecContent = await pubspecFile.readAsString();
  final pubspec = loadYaml(pubspecContent);
  final packageName = pubspec['name'];

  // If we're in dart_lmdb2, use the embedded version to ensure accuracy
  if (packageName == 'dart_lmdb2') {
    return dartLmdb2Version;
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

  // For any other consumer package, use the embedded version
  return dartLmdb2Version;
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

/// Verifies checksums of all extracted files against the manifest
Future<void> verifyChecksums(String nativePath) async {
  final manifestFile = File(path.join(nativePath, 'manifest.json'));

  if (!manifestFile.existsSync()) {
    throw Exception('Manifest file not found after extraction');
  }

  print('Verifying checksums...');
  final manifestContent = await manifestFile.readAsString();
  final manifest = jsonDecode(manifestContent);
  final platforms = manifest['platforms'] as Map<String, dynamic>;

  for (final entry in platforms.entries) {
    final platformName = entry.key;
    final platformData = entry.value as Map<String, dynamic>;
    final filePath = path.join(nativePath, platformData['path']);
    final expectedChecksum = platformData['sha256'];

    final file = File(filePath);
    if (!file.existsSync()) {
      print('Warning: File not found for $platformName: $filePath');
      continue;
    }

    // Calculate checksum
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final actualChecksum = digest.toString();

    if (actualChecksum != expectedChecksum) {
      throw Exception(
          'Checksum mismatch for $platformName: expected $expectedChecksum, got $actualChecksum');
    }
  }

  print('All checksums verified successfully');
}

/// Calculates SHA256 checksum of a file
Future<String> calculateFileChecksum(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception('File not found: $filePath');
  }

  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}
