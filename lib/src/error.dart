import 'source.dart';

/// A configuration error occurs when configuration is invalid.
class ConfigurationError implements Exception {
  /// Creates a new configuration error for the given [source] and [key] with
  /// the given [message].
  ConfigurationError(this.message, {this.source, this.key});

  /// The source that contains the invalid configuration, if any.
  final ConfigurationSource? source;

  /// The key that points to the invalid configuration in [source], if any.
  final ConfigurationKey? key;

  /// A messages describing the error.
  final String message;

  /// A human readable description of the error.
  String get description {
    final stringBuffer = StringBuffer();

    if (source != null && key != null) {
      stringBuffer.write('${source!.describeKey(key!)}: ');
    }

    stringBuffer.write(message);

    return stringBuffer.toString();
  }

  @override
  String toString() => 'ConfigurationError: $description';
}
