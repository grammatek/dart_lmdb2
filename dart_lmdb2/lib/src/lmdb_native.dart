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

  DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      // for iOS the library is statically linked
      return DynamicLibrary.process();
    }

    final libraryPath = _resolveLibraryPath();
    return DynamicLibrary.open(libraryPath);
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

    final libName = Platform.isWindows
        ? 'lmdb.dll'
        : Platform.isMacOS
            ? 'liblmdb.dylib'
            : 'liblmdb.so';

    final Uri packageUri = Uri.parse('package:dart_lmdb2/src/native/$libName');
    final Uri? fileUri = Isolate.resolvePackageUriSync(packageUri);

    if (fileUri == null) {
      throw FileSystemException('Could not resolve native library path');
    }
    return fileUri.toFilePath();
  }
}
