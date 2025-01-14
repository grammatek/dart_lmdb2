import 'dart:io';
import 'package:path/path.dart' as path;
import 'build_exception.dart';

/// Get the platform-specific library name
String _getPlatformLibraryName() {
  if (Platform.isWindows) {
    return 'lmdb.dll';
  } else if (Platform.isMacOS) {
    return 'liblmdb.dylib';
  } else if (Platform.isLinux) {
    return 'liblmdb.so';
  } else if (Platform.isIOS) {
    return 'liblmdb.a';
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
  final platformDir = Directory(path.join(
    projectDir.path,
    'lib',
    'src',
    'native',
    Platform.operatingSystem, // 'windows', 'linux', 'macos'
  ));

  if (!platformDir.existsSync()) {
    print('Creating platform directory...');
    platformDir.createSync(recursive: true);
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

  print('Build completed successfully!');
}
