import 'package:dart_lmdb2/src/build_util.dart';
import 'dart:io';

void main(List<String> args) async {
  // When running as tool, use parent directory
  final projectDir = File(Platform.script.toFilePath()).parent.parent;
  try {
    if (args.contains('--ios')) {
      await buildIosLibrary(projectDir);
    } else if (args.contains('--android')) {
      await buildAndroidLibrary(projectDir);
    } else {
      await buildNativeLibrary(projectDir);
    }
  } catch (e) {
    print('Build failed: $e');
    exit(1);
  }
}
