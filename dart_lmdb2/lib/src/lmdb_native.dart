import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'generated_bindings.dart';

/// Singleton for managing LMDB native library access
class LMDBNative {
  static LMDBNative? _instance;
  late final NativeLibrary lib;

  // Private constructor
  LMDBNative._() {
    lib = NativeLibrary(_openLibrary());
  }

  // Singleton-acces via lazy initialization
  static LMDBNative get instance {
    return _instance ??= LMDBNative._();
  }

  DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      // for iOS the library is statically linked
      return DynamicLibrary.process();
    }

    final libraryPath = _resolveLibraryPath();
    return DynamicLibrary.open(libraryPath);
  }

  String _resolveLibraryPath() {
    if (Platform.isIOS) {
      throw UnsupportedError(
          'iOS uses static linking, no path resolution needed');
    }

    final libName = Platform.isWindows
        ? 'lmdb.dll'
        : Platform.isMacOS
            ? 'liblmdb.dylib'
            : Platform.isLinux
                ? 'liblmdb.so'
                : throw UnsupportedError('Unsupported platform');

    // Resolve package URI to File-URI: this is the only portable way I found
    final Uri packageUri = Uri.parse('package:dart_lmdb2/src/native/$libName');
    final Uri? fileUri = Isolate.resolvePackageUriSync(packageUri);

    if (fileUri == null) {
      throw FileSystemException('Could not resolve native library path');
    }
    final nativeLibPath = fileUri.toFilePath();
    // print('nativeLibPath: $nativeLibPath');
    return nativeLibPath;
  }
}
