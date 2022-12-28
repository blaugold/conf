import 'source.dart';

/// A configuration error occurs when configuration is invalid.
class ConfigurationError implements Exception {
  /// Creates a new configuration error for the given [source] and [key] with
  /// the given [message].
  ConfigurationError(this.message, {required this.source, required this.key});

  /// The source that contains the invalid configuration.
  final ConfigurationSource source;

  /// The key that points to the invalid configuration in [source].
  final ConfigurationKey key;

  /// A messages describing the error.
  final String message;

  @override
  String toString() =>
      'Configuration error for ${source.describeKey(key)}:\n$message';
}
