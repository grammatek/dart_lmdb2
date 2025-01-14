import 'dart:io';
import 'package:path/path.dart' as path;
import 'build_exception.dart';

/// Build the iOS library
Future<void> buildIosLibrary(Directory projectDir) async {
  print('Building LMDB for iOS...');

  final buildDirDevice =
      Directory(path.join(projectDir.path, 'build-ios-device'));
  final buildDirSimulator =
      Directory(path.join(projectDir.path, 'build-ios-simulator'));

  // Device build (arm64)
  print('\nBuilding for iOS Device (arm64)...');
  var result = await Process.run(
    'cmake',
    [
      '-S',
      '.',
      '-B',
      buildDirDevice.path,
      '-GXcode',
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0',
      '-DCMAKE_OSX_ARCHITECTURES=arm64',
      '-DIOS=TRUE',
      '-DCMAKE_BUILD_TYPE=Release',
      '-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO',
    ],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'CMake iOS device configuration failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  result = await Process.run(
    'cmake',
    ['--build', buildDirDevice.path, '--config', 'Release'],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'iOS device build failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Simulator build (x86_64)
  print('\nBuilding for iOS Simulator (x86_64)...');
  result = await Process.run(
    'cmake',
    [
      '-S',
      '.',
      '-B',
      buildDirSimulator.path,
      '-GXcode',
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0',
      '-DCMAKE_OSX_ARCHITECTURES=x86_64',
      '-DIOS=TRUE',
      '-DCMAKE_OSX_SYSROOT=iphonesimulator',
      '-DCMAKE_BUILD_TYPE=Release',
      '-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO',
    ],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'CMake iOS simulator configuration failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  result = await Process.run(
    'cmake',
    ['--build', buildDirSimulator.path, '--config', 'Release'],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'iOS simulator build failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Get paths to built libraries
  final deviceLib = File(path.join(buildDirDevice.path, 'lib', 'liblmdb.a'));
  final simulatorLib =
      File(path.join(buildDirSimulator.path, 'lib', 'liblmdb.a'));

  // Verify libraries and check architectures
  print('\nChecking library paths and architectures:');
  for (final lib in [deviceLib, simulatorLib]) {
    if (!lib.existsSync()) {
      throw BuildException('Missing library: ${lib.path}', 1);
    }
    result = await Process.run('lipo', ['-info', lib.path]);
    print('${lib.path}:');
    print(result.stdout);
  }

  // Create target directory
  final iosDir = Directory(path.join(
    projectDir.path,
    'lib',
    'src',
    'native',
    'ios',
  ));
  if (!iosDir.existsSync()) {
    iosDir.createSync(recursive: true);
  }

  final universalLib = File(path.join(iosDir.path, 'liblmdb.a'));

  // Create universal binary
  print('\nCreating universal binary...');
  result = await Process.run(
    'lipo',
    [
      '-create',
      deviceLib.path,
      simulatorLib.path,
      '-output',
      universalLib.path,
    ],
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'Failed to create universal binary:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Verify final binary
  print('\nVerifying architectures in universal binary:');
  result = await Process.run('lipo', ['-info', universalLib.path]);
  print(result.stdout);

  print('\niOS build completed successfully!');
  print('Universal library created at: ${universalLib.path}');
}
