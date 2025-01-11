import 'dart:io';
import 'package:path/path.dart' as path;

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
  final iosDir = Directory(path.join(projectDir.path, 'ios'));
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

/// Get the platform-specific library name
String _getPlatformLibraryName() {
  if (Platform.isWindows) {
    return 'lmdb.dll';
  } else if (Platform.isMacOS) {
    return 'liblmdb.dylib';
  } else if (Platform.isLinux) {
    return 'liblmdb.so';
  } else if (Platform.isIOS) {
    return 'liblmdb.a'; // Static library for iOS
  }
  throw BuildException(
    'Unsupported platform: ${Platform.operatingSystem}',
    1,
  );
}

/// Build the native library in the specified project directory
Future<void> buildNativeLibrary(Directory projectDir) async {
  print('Building LMDB native library...');
  print('Project directory: ${projectDir.path}');

  // Create build directory
  final buildDir = Directory(path.join(projectDir.path, 'build'));
  if (!buildDir.existsSync()) {
    print('Creating build directory...');
    buildDir.createSync();
  }

  // CMake configuration
  print('Configuring CMake...');
  var result = await Process.run(
    'cmake',
    [
      '-S',
      '.',
      '-B',
      'build',
      '-DCMAKE_BUILD_TYPE=Release',
      '--debug-output',
      '-DCMAKE_VERBOSE_MAKEFILE=ON',
    ],
    workingDirectory: projectDir.path,
  );

  print('\nCMake configuration output:');
  print(result.stdout);
  if (result.stderr.toString().isNotEmpty) {
    print('CMake configuration warnings/errors:');
    print(result.stderr);
  }

  if (result.exitCode != 0) {
    throw BuildException(
      'CMake configuration failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Build
  print('Building...');

  // Platform-specific build commands
  if (Platform.isWindows) {
    // For Visual Studio: Use /verbosity:detailed
    result = await Process.run(
      'cmake',
      [
        '--build', 'build',
        '--config', 'Release',
        '--verbose',
        '--', // Pass following arguments to the native build tool
        '/verbosity:normal',
        '/p:PreferredToolArchitecture=x64', // Use 64-bit tools
        '/clp:ShowCommandLine', // Show complete command lines
      ],
      workingDirectory: projectDir.path,
    );
  } else {
    // For Unix makefiles: Use VERBOSE=1
    result = await Process.run(
      'cmake',
      [
        '--build', 'build',
        '--config', 'Release',
        '--verbose',
        '--', // Pass following arguments to the native build tool
        'VERBOSE=1', // Show complete command lines
      ],
      workingDirectory: projectDir.path,
    );
  }

  print('\nBuild output:');
  print(result.stdout);
  if (result.stderr.toString().isNotEmpty) {
    print('Build warnings/errors:');
    print(result.stderr);
  }

  if (result.exitCode != 0) {
    throw BuildException(
      'Build failed:\n${result.stderr}',
      result.exitCode,
    );
  }

  // Copy the library to the lib directory
  final libDir = Directory(path.join(projectDir.path, 'lib', 'src', 'native'));
  if (!libDir.existsSync()) {
    print('Creating native library directory...');
    libDir.createSync(recursive: true);
  }

  final String libraryName = _getPlatformLibraryName();
  final File builtLib;

  if (Platform.isWindows) {
    // Windows legt die DLL in verschiedene mögliche Verzeichnisse
    final possiblePaths = [
      path.join(buildDir.path, 'lib', 'Release', libraryName),
      path.join(buildDir.path, 'Release', libraryName),
      path.join(buildDir.path, 'bin', 'Release', libraryName),
      path.join(buildDir.path, 'bin', libraryName),
      path.join(buildDir.path, 'x64', 'Release', libraryName),
    ];

    builtLib = possiblePaths.map((p) => File(p)).firstWhere(
      (f) => f.existsSync(),
      orElse: () {
        print('Searched for library in:');
        for (final p in possiblePaths) {
          print('  $p');
        }
        throw BuildException(
          'Could not find built library. Searched in: ${possiblePaths.join(", ")}',
          1,
        );
      },
    );
  } else {
    // Unix-ähnliche Systeme
    builtLib = File(path.join(buildDir.path, 'lib', libraryName));
  }

  final targetLib = File(path.join(libDir.path, libraryName));

  if (builtLib.existsSync()) {
    builtLib.copySync(targetLib.path);
    print('Library successfully built and copied to: ${targetLib.path}');
  } else {
    print('Build directory contents:');
    buildDir.listSync(recursive: true).forEach((entity) {
      print('  ${entity.path}');
    });
    throw BuildException(
      'Could not find built library: ${builtLib.path}',
      1,
    );
  }

  print('Build completed successfully!');
}

/// Exception thrown during the build process
class BuildException implements Exception {
  final String message;
  final int exitCode;

  BuildException(this.message, this.exitCode);

  @override
  String toString() => message;
}
