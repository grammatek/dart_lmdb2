import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dart_lmdb2/src/build_exception.dart';

final List<String> androidAbis = [
  // no 32-bit archs supported, as disallowed in Google Play since August 2021
  'arm64-v8a',
  'x86_64',
];

Future<void> buildAndroidLibrary(Directory projectDir) async {
  print('Building LMDB for Android...');

  final ndkPath = Platform.environment['ANDROID_NDK_HOME'];
  if (ndkPath == null) {
    throw BuildException(
      'ANDROID_NDK_HOME environment variable not set',
      1,
    );
  }

  for (final abi in androidAbis) {
    print('\nBuilding for Android $abi...');
    final buildDir =
        Directory(path.join(projectDir.path, 'build-android-$abi'));

    // CMake configuration
    var result = await Process.run(
      'cmake',
      [
        '-S',
        '.',
        '-B',
        buildDir.path,
        '-DCMAKE_TOOLCHAIN_FILE=$ndkPath/build/cmake/android.toolchain.cmake',
        '-DANDROID_ABI=$abi',
        '-DANDROID_PLATFORM=android-21',
        '-DCMAKE_BUILD_TYPE=Release',
      ],
      workingDirectory: projectDir.path,
    );

    if (result.exitCode != 0) {
      throw BuildException(
        'CMake Android configuration failed for $abi:\n${result.stderr}',
        result.exitCode,
      );
    }

    // Build
    result = await Process.run(
      'cmake',
      ['--build', buildDir.path, '--config', 'Release'],
      workingDirectory: projectDir.path,
    );

    if (result.exitCode != 0) {
      throw BuildException(
        'Android build failed for $abi:\n${result.stderr}',
        result.exitCode,
      );
    }

    // Create target directory
    final targetDir = Directory(path.join(
      projectDir.path,
      'lib',
      'src',
      'native',
      'android',
      abi,
    ));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // Copy library
    final builtLib = File(path.join(buildDir.path, 'lib', 'liblmdb.so'));
    final targetLib = File(path.join(targetDir.path, 'liblmdb.so'));

    if (builtLib.existsSync()) {
      builtLib.copySync(targetLib.path);
      print('Library for $abi copied to: ${targetLib.path}');
    } else {
      throw BuildException(
        'Could not find built library for $abi: ${builtLib.path}',
        1,
      );
    }
  }

  print('\nAndroid build completed successfully!');
}
