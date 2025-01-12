/// Exception thrown during the build process
class BuildException implements Exception {
  final String message;
  final int exitCode;

  BuildException(this.message, this.exitCode);

  @override
  String toString() => message;
}
