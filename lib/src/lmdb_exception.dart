import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'lmdb_native.dart';

class LMDBException implements Exception {
  final String message;
  final int errorCode;
  late final String errorString;

  LMDBException(this.message, this.errorCode) {
    // Lazy access to native library through singleton
    final ptr = LMDBNative.instance.lib.mdb_strerror(errorCode);
    errorString = ptr.cast<Utf8>().toDartString();
  }

  @override
  String toString() =>
      'LMDBException: $message (error: $errorString, code: $errorCode)';
}
