import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dart_lmdb2/src/build_exception.dart';

/// Build the iOS library
Future<void> buildIosLibrary(Directory projectDir) async {
  print('Building LMDB for iOS...');

  final buildDirDevice =
      Directory(path.join(projectDir.path, 'build-ios-device'));
  final buildDirSimulatorX64 =
      Directory(path.join(projectDir.path, 'build-ios-simulator-x86_64'));
  final buildDirSimulatorArm64 =
      Directory(path.join(projectDir.path, 'build-ios-simulator-arm64'));

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

  // Simulator build (x86_64) - for Intel Macs
  print('\nBuilding for iOS Simulator (x86_64)...');
  result = await Process.run(
    'cmake',
    [
      '-S',
      '.',
      '-B',
      buildDirSimulatorX64.path,
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
      'CMake iOS simulator x86_64 configuration failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  result = await Process.run(
    'cmake',
    ['--build', buildDirSimulatorX64.path, '--config', 'Release'],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'iOS simulator x86_64 build failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Simulator build (arm64) - for Apple Silicon Macs
  print('\nBuilding for iOS Simulator (arm64)...');
  result = await Process.run(
    'cmake',
    [
      '-S',
      '.',
      '-B',
      buildDirSimulatorArm64.path,
      '-GXcode',
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0',
      '-DCMAKE_OSX_ARCHITECTURES=arm64',
      '-DIOS=TRUE',
      '-DCMAKE_OSX_SYSROOT=iphonesimulator',
      '-DCMAKE_BUILD_TYPE=Release',
      '-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO',
    ],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'CMake iOS simulator arm64 configuration failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  result = await Process.run(
    'cmake',
    ['--build', buildDirSimulatorArm64.path, '--config', 'Release'],
    workingDirectory: projectDir.path,
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'iOS simulator arm64 build failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Get paths to built libraries
  final deviceLib = File(path.join(buildDirDevice.path, 'lib', 'liblmdb.a'));
  final simulatorX64Lib =
      File(path.join(buildDirSimulatorX64.path, 'lib', 'liblmdb.a'));
  final simulatorArm64Lib =
      File(path.join(buildDirSimulatorArm64.path, 'lib', 'liblmdb.a'));

  // Verify libraries and check architectures
  for (final lib in [deviceLib, simulatorX64Lib, simulatorArm64Lib]) {
    if (!lib.existsSync()) {
      throw BuildException('Missing library: ${lib.path}', 1);
    }
  }

  // Create separate target directories for device and simulator
  final iosBaseDir = Directory(path.join(
    projectDir.path,
    'lib',
    'src',
    'native',
    'ios',
  ));
  if (!iosBaseDir.existsSync()) {
    iosBaseDir.createSync(recursive: true);
  }

  // Device directory
  final iosDeviceDir = Directory(path.join(iosBaseDir.path, 'device'));
  if (!iosDeviceDir.existsSync()) {
    iosDeviceDir.createSync(recursive: true);
  }

  // Simulator directory
  final iosSimulatorDir = Directory(path.join(iosBaseDir.path, 'simulator'));
  if (!iosSimulatorDir.existsSync()) {
    iosSimulatorDir.createSync(recursive: true);
  }

  // Copy device library
  final deviceTargetLib = File(path.join(iosDeviceDir.path, 'liblmdb.a'));
  deviceLib.copySync(deviceTargetLib.path);

  // Create universal simulator library with both x86_64 and arm64 architectures
  final simulatorTargetLib = File(path.join(iosSimulatorDir.path, 'liblmdb.a'));
  result = await Process.run(
    'lipo',
    [
      '-create',
      simulatorX64Lib.path,
      simulatorArm64Lib.path,
      '-output',
      simulatorTargetLib.path,
    ],
  );

  if (result.exitCode != 0) {
    throw BuildException(
      'Failed to create universal simulator binary:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Verify libraries
  print('\nVerifying architectures in device library:');
  result = await Process.run('lipo', ['-info', deviceTargetLib.path]);
  print(result.stdout);

  print('\nVerifying architectures in simulator library:');
  result = await Process.run('lipo', ['-info', simulatorTargetLib.path]);
  print(result.stdout);

  print('\niOS build completed successfully!');
  print('Libraries created at:');
  print('  Device: ${deviceTargetLib.path}');
  print('  Simulator: ${simulatorTargetLib.path} (universal x86_64 + arm64)');
}
