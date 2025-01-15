import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;

/// Resolves the base path to the package
/// Returns null if package cannot be found
Directory? resolvePackageBase(String packageName) {
  final normalizedName =
      packageName.endsWith('/') ? packageName : '$packageName/';
  final packageUri = Uri.parse('package:$normalizedName');
  final Uri? resolvedUri = Isolate.resolvePackageUriSync(packageUri);

  if (resolvedUri == null) {
    print('Error: Could not resolve package "$packageName"');
    return null;
  }

  return Directory.fromUri(resolvedUri);
}

/// Resolves the full path to the native directory within the package
/// Returns null if either package or directory cannot be resolved
Directory? resolveNativeDir(String packageName) {
  final packageDir = resolvePackageBase(packageName);
  if (packageDir == null) return null;

  final nativePath = path.join(packageDir.path, 'src', 'native');
  return Directory(nativePath);
}

/// Checks if source file needs to be copied based on modification time
/// Returns true if target doesn't exist or source is newer
Future<bool> shouldCopyFile(File source, String targetPath) async {
  final targetFile = File(targetPath);

  if (!await targetFile.exists()) {
    return true;
  }

  final sourceModified = await source.lastModified();
  final targetModified = await targetFile.lastModified();

  return sourceModified.isAfter(targetModified);
}

/// Copies all files and directories recursively from source to destination
/// Only copies files that are newer or don't exist in target
Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!await destination.exists()) {
    await destination.create(recursive: true);
  }

  await for (final entity in source.list(recursive: false)) {
    final entityName = path.basename(entity.path);
    final destPath = path.join(destination.path, entityName);

    if (entity is Directory) {
      final newDir = Directory(destPath);
      await copyDirectory(entity, newDir);
    } else if (entity is File) {
      if (await shouldCopyFile(entity, destPath)) {
        await entity.copy(destPath);
        print('$entityName');
      } else {
        print('$entityName skipped (not modified)');
      }
    }
  }
}

Future<void> main() async {
  final packageName = 'dart_lmdb2';

  // Get source directory from package
  final sourceDir = resolveNativeDir(packageName);
  if (sourceDir == null) {
    print('Error: Could not resolve native directory in package $packageName');
    exit(1);
  }

  // Define target directory in local project
  final targetDir = Directory('lib/src/native');

  try {
    // Perform the copy operation
    print('Copying native library files');
    print('  Source: ${sourceDir.path}');
    print('  Target: ${targetDir.path}');
    await copyDirectory(sourceDir, targetDir);
  } catch (e) {
    print('Error during copy operation: $e');
    exit(1);
  }
}
