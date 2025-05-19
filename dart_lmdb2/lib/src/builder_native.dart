import 'dart:io';
import 'package:path/path.dart' as path;
import 'build_exception.dart';

/// Get the platform-specific library names
List<String> _getPlatformLibraryNames() {
  if (Platform.isWindows) {
    return ['lmdb.dll', 'lmdb_static.lib'];
  } else if (Platform.isMacOS) {
    return ['liblmdb.dylib', 'liblmdb.a'];
  } else if (Platform.isLinux) {
    return ['liblmdb.so', 'liblmdb.a'];
  } else if (Platform.isIOS) {
    return ['liblmdb.a'];
  }
  throw BuildException(
    'Unsupported platform: ${Platform.operatingSystem}',
    1,
  );
}

/// Get platform-specific search paths
List<String> _getWindowsSearchPaths(String buildDir, String libraryName) {
  if (libraryName.endsWith('.lib')) {
    return [path.join(buildDir, 'lib', 'lmdb_static.lib')];
  }

  return [
    path.join(buildDir, 'bin', libraryName),
    path.join(buildDir, 'bin', 'Release', libraryName),
  ];
}

/// Build the native library in the specified project directory
Future<void> buildNativeLibrary(Directory projectDir) async {
  print('Building LMDB native libraries...');
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
      '-DBUILD_SHARED_LIBS=ON',
      '-DBUILD_STATIC_LIBS=ON',
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

  // Copy the libraries to the lib directory
  final platformDir = Directory(path.join(
    projectDir.path,
    'lib',
    'src',
    'native',
    Platform.operatingSystem,
  ));

  if (!platformDir.existsSync()) {
    print('Creating platform directory...');
    platformDir.createSync(recursive: true);
  }

  // Copy all library types for the platform
  for (final libraryName in _getPlatformLibraryNames()) {
    final File builtLib;

    if (Platform.isWindows) {
      final possiblePaths = _getWindowsSearchPaths(buildDir.path, libraryName);

      if (possiblePaths.isEmpty) {
        throw BuildException(
          'Could not find built library: $libraryName',
          1,
        );
      }

      builtLib = File(possiblePaths.first);
    } else {
      // Unixoid systems
      builtLib = File(path.join(buildDir.path, 'lib', libraryName));
    }

    final targetLib = File(path.join(platformDir.path, libraryName));

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
  }

  print('Build completed successfully!');
}
