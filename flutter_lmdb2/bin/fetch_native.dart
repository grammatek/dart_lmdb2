import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  // Find plugin directory using package config
  final packageUri =
      await Isolate.resolvePackageUri(Uri.parse('package:flutter_lmdb2/'));
  if (packageUri == null) {
    print('Error: Could not resolve package:flutter_lmdb2');
    exit(1);
  }

  // Construct path to original script
  final pluginRoot = path.dirname(packageUri.toFilePath());
  final toolScript = path.join(pluginRoot, 'tool', 'fetch_native.dart');

  // Check if script exists
  if (!File(toolScript).existsSync()) {
    print('Error: Could not find fetch_native.dart at $toolScript');
    exit(1);
  }

  // Execute original script
  final result = await Process.run(
    'dart',
    [toolScript, ...args],
    workingDirectory: pluginRoot,
  );

  // Forward output
  stdout.write(result.stdout);
  stderr.write(result.stderr);

  // Exit with same code as original script
  exit(result.exitCode);
}
