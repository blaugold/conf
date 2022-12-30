import 'source.dart';

/// A configuration error occurs when configuration is invalid.
class ConfigurationError {
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

    stringBuffer.write(message.trim());

    return stringBuffer.toString();
  }
}

/// An exception that is thrown when configuration is invalid.
///
/// It contains at least one [ConfigurationError] in [errors].
class ConfigurationException implements Exception {
  /// Creates a new configuration exception with the given [errors].
  ///
  /// If [errors] is empty, an [ArgumentError] is thrown.
  ConfigurationException(this.errors) {
    if (errors.isEmpty) {
      throw ArgumentError.value(errors, 'errors', 'must not be empty');
    }
  }

  /// Executes [fn] and collects the [ConfigurationError]s from any thrown
  /// [ConfigurationException] into [errors].
  ///
  /// This is useful when you want to collect all errors from multiple calls
  /// that might throw [ConfigurationException]s.
  static Future<void> collectErrors(
    List<ConfigurationError> errors,
    Future<void> Function() fn,
  ) async {
    try {
      return await fn();
    } on ConfigurationException catch (error) {
      errors.addAll(error.errors);
    }
  }

  /// The configuration errors that caused this exception.
  final List<ConfigurationError> errors;

  @override
  String toString() {
    final stringBuffer = StringBuffer();

    stringBuffer.writeln('Configuration errors:');

    var i = 0;
    for (final error in errors) {
      stringBuffer
        ..write((i++) + 1)
        ..write('. ')
        ..write(error.description.indentNewLines(' ' * 3));

      if (i < errors.length) {
        stringBuffer.writeln();
      }
    }

    return stringBuffer.toString();
  }
}

extension on String {
  String indentNewLines(String indent) => replaceAll('\n', '\n$indent');
}
