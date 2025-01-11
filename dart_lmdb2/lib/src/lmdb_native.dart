import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
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
    final libraryPath = _resolveLibraryPath();
    return DynamicLibrary.open(libraryPath);
  }

  String _resolveLibraryPath() {
    final libDir = path.join(Directory.current.path, 'lib', 'src', 'native');

    if (Platform.isWindows) {
      return path.join(libDir, 'lmdb.dll');
    } else if (Platform.isMacOS) {
      return path.join(libDir, 'liblmdb.dylib');
    } else if (Platform.isLinux) {
      return path.join(libDir, 'liblmdb.so');
    }

    throw UnsupportedError('Unsupported platform');
  }
}
