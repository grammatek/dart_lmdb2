class LMDBException implements Exception {
  final String message;
  final int errorCode;

  LMDBException(this.message, this.errorCode);

  @override
  String toString() => 'LMDBException: $message (error code: $errorCode)';
}
