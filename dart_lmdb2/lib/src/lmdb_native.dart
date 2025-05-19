import 'dart:ffi' show Abi, DynamicLibrary;
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

  bool _isStaticallyLinked() {
    try {
      final processLib = DynamicLibrary.process();
      processLib.lookup('mdb_env_create');
      // throws exception if the symbol is unknown
      return true;
    } catch (e) {
      return false;
    }
  }

  DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      // for iOS the library is statically linked
      return DynamicLibrary.process();
    }

    if (Platform.isMacOS && _isStaticallyLinked()) {
      // for MacOS the library might be statically linked, if used as Flutter
      // plugin, but for normal Dart usage, it's still a dynamic lib
      return DynamicLibrary.process();
    }

    // For all other platforms including Android, use path resolution
    return DynamicLibrary.open(_resolveLibraryPath());
  }

  String _getAndroidAbi() {
    switch (Abi.current()) {
      case Abi.androidArm64:
        return 'arm64-v8a';
      case Abi.androidX64:
        return 'x86_64';
      default:
        print(
            'Warning: Unexpected ABI ${Abi.current()}, falling back to arm64-v8a');
        return 'arm64-v8a';
    }
  }

  String _resolveLibraryPath() {
    if (Platform.isIOS) {
      throw UnsupportedError(
          'iOS uses static linking, no path resolution needed');
    }

    if (Platform.isAndroid) {
      final abi = _getAndroidAbi();
      final libName = 'liblmdb.so';
      final packageUri =
          Uri.parse('package:dart_lmdb2/src/native/android/$abi/$libName');
      final Uri? fileUri = Isolate.resolvePackageUriSync(packageUri);
      if (fileUri == null) {
        throw FileSystemException(
            'Could not resolve Android native library path');
      }
      return fileUri.toFilePath();
    }

    final platform = Platform.operatingSystem; // 'windows', 'macos', 'linux'
    final libName = Platform.isWindows
        ? 'lmdb.dll'
        : Platform.isMacOS
            ? 'liblmdb.dylib'
            : 'liblmdb.so';

    final Uri packageUri =
        Uri.parse('package:dart_lmdb2/src/native/$platform/$libName');
    final Uri? fileUri = Isolate.resolvePackageUriSync(packageUri);

    if (fileUri == null) {
      throw FileSystemException('Could not resolve native library path');
    }
    return fileUri.toFilePath();
  }
}
