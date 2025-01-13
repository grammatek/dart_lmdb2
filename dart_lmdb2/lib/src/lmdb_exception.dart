import 'package:ffi/ffi.dart';
import 'lmdb_native.dart';

/// Exception class for LMDB-specific errors.
///
/// This class provides detailed error information including:
/// * A human-readable message
/// * The native LMDB error code
/// * The corresponding error string from the LMDB library
///
/// Example:
/// ```dart
/// try {
///   await db.put(txn, 'key', 'value');
/// } catch (e) {
///   if (e is LMDBException) {
///     print('LMDB error: ${e.errorString}');
///     print('Error code: ${e.errorCode}');
///   }
/// }
/// ```
class LMDBException implements Exception {
  /// Custom error message describing the context of the error.
  final String message;

  /// Native LMDB error code.
  ///
  /// This corresponds to the error codes defined in the LMDB C library.
  final int errorCode;

  /// Corresponding error string from the LMDB library.
  ///
  /// This is automatically retrieved from the native LMDB library
  /// using `mdb_strerror`.
  late final String errorString;

  /// Creates a new LMDB exception with the given message and error code.
  ///
  /// The [errorString] is automatically populated by calling the native
  /// LMDB `mdb_strerror` function.
  ///
  /// Example:
  /// ```dart
  /// throw LMDBException('Failed to open database', -30781);
  /// ```
  LMDBException(this.message, this.errorCode) {
    // Lazy access to native library through singleton
    final ptr = LMDBNative.instance.lib.mdb_strerror(errorCode);
    errorString = ptr.cast<Utf8>().toDartString();
  }

  /// Returns a formatted string representation of the exception.
  ///
  /// The string includes the message, error string, and error code
  /// for comprehensive error reporting.
  @override
  String toString() =>
      'LMDBException: $message (error: $errorString, code: $errorCode)';
}
