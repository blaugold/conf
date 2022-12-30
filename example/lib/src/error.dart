abstract class FatalException implements Exception {
  factory FatalException([int exitCode]) = _FatalException;

  int get exitCode;
}

class _FatalException implements FatalException {
  const _FatalException([this.exitCode = 1]);

  @override
  final int exitCode;

  @override
  String toString() => 'FatalException: exitCode $exitCode';
}
