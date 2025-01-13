import 'package:dart_lmdb2/src/build_util.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  try {
    final packageDir = _findPackageDir();
    print('Package directory: ${packageDir.path}');

    if (args.contains('--ios')) {
      await buildIosLibrary(packageDir);
    } else {
      await buildNativeLibrary(packageDir);
    }
  } catch (e) {
    print('Build failed: $e');
    exit(1);
  }
}

Directory _findPackageDir() {
  var current = File(Platform.script.toFilePath()).parent;

  while (current.path != current.parent.path) {
    final pubspecFile = File(path.join(current.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      return current;
    }
    current = current.parent;
  }

  final packageDir = Directory(path.join(
      File(Platform.script.toFilePath())
          .parent
          .parent
          .parent
          .parent
          .parent
          .path,
      'packages',
      'dart_lmdb2'));

  if (packageDir.existsSync()) {
    return packageDir;
  }

  throw Exception('Could not find package directory');
}
