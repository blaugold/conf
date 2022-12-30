import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'error.dart';

/// A key for which a [ConfigurationSource] might have a value.
///
/// A key points to a location in a structure of nested maps and lists. This
/// location is stored in [path] as a list of [String]s and [int]s. [String]s
/// represent keys in maps, and [int]s represent indices in lists.
@immutable
class ConfigurationKey {
  /// Creates a [ConfigurationKey] from a list of strings and integers
  /// representing the key's [path].
  ///
  /// [path] must not be empty, and must only contain [String]s and [int]s.
  ///
  /// [path] must not contain empty strings, and must not contain strings
  /// containing ".".
  ConfigurationKey(this.path) {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'must not be empty');
    }

    for (final segment in path) {
      if (segment is! String && segment is! int) {
        throw ArgumentError.value(
          path,
          'path',
          'must only contain strings and integers',
        );
      }

      if (segment is String) {
        if (segment.isEmpty) {
          throw ArgumentError.value(
            path,
            'path',
            'must not contain empty strings',
          );
        }
        if (segment.contains('.')) {
          throw ArgumentError.value(
            path,
            'path',
            'must not contain strings containing "."',
          );
        }
      }
    }
  }

  /// The path of this key.
  ///
  /// The path is a list of [String]s and [int]s representing the key's location
  /// in a nested structure of maps and lists.
  final List<Object> path;

  /// Returns a new [ConfigurationKey] that is the concatenation of this key and
  /// [other].
  ///
  /// If [other] is a [ConfigurationKey], its path is appended to this key's
  /// path.
  ConfigurationKey operator +(Object other) => ConfigurationKey([
        ...path,
        if (other is ConfigurationKey) ...other.path else other,
      ]);

  @override
  int get hashCode => const DeepCollectionEquality().hash(path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigurationKey &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(path, other.path);

  @override
  String toString() {
    final stringBuffer = StringBuffer();
    var isFirst = true;
    for (final segment in path) {
      if (segment is String) {
        if (!isFirst) {
          stringBuffer.write('.');
        }
        stringBuffer.write(segment);
      } else {
        stringBuffer
          ..write('[')
          ..write(segment)
          ..write(']');
      }
      isFirst = false;
    }
    return stringBuffer.toString();
  }
}

/// A source of configuration values.
///
/// A source is a collection of key-value pairs, where the keys are
/// [ConfigurationKey]s and the values are strings.
abstract class ConfigurationSource {
  /// Returns a description of this source.
  String get description;

  /// Returns the value of the configuration under [key] as a string, or `null`
  String? operator [](ConfigurationKey key);

  /// Returns whether this source contains any values under [key] or any values
  /// whose keys are prefixed by [key].
  bool contains(ConfigurationKey key);

  /// Returns a string describing a [key] in this source.
  ///
  /// The description should match the format of the source, for example, if the
  /// source are environment variables, the description should be the name of
  /// the environment variable.
  String describeKey(ConfigurationKey key);
}

/// A [ConfigurationSource] that is a combination of other
/// [ConfigurationSource]s.
///
/// The value of a key is the value of the first source that contains a value
/// for that key. The order of the sources when constructing a
/// [CombiningSource] determines the priority of the sources. The first source
/// in the list has the highest priority and the last source in the list has the
/// lowest priority.
class CombiningSource extends ConfigurationSource {
  /// Creates a [CombiningSource] from a list of [ConfigurationSource]s.
  ///
  /// The order of the sources determines the priority of the sources. The first
  /// source in the list has the highest priority and the last source in the
  /// list has the lowest priority.
  CombiningSource([List<ConfigurationSource>? sources])
      : _sources = List.of(sources ?? <ConfigurationSource>[]);

  final List<ConfigurationSource> _sources;

  @override
  String get description => 'combining source';

  @override
  String? operator [](ConfigurationKey key) {
    for (final source in _sources) {
      final value = source[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  @override
  bool contains(ConfigurationKey key) {
    for (final source in _sources) {
      if (source.contains(key)) {
        return true;
      }
    }
    return false;
  }

  @override
  String describeKey(ConfigurationKey key) {
    for (final source in _sources) {
      final value = source[key];
      if (value != null) {
        return '${source.describeKey(key)} from ${source.description}';
      }
    }
    return key.toString();
  }

  /// Adds [source] to the end of the list of sources.
  ///
  /// The source will have the lowest priority relative to the already added
  /// sources.
  void add(ConfigurationSource source) {
    _sources.add(source);
  }

  /// Adds all of the sources in [sources] to the end of the list of sources.
  ///
  /// The sources will have the lowest priority relative to the already added
  /// sources.
  void addAll(Iterable<ConfigurationSource> sources) {
    _sources.addAll(sources);
  }
}

/// A [ConfigurationSource] that reads configuration values from a map of
/// environment variables such as [Platform.environment].
///
/// Matching of environment variable names is case-insensitive. The name of an
/// environment variable is the concatenation of the segments of the key's path
/// with underscores between segments. For example, the key `foo[0].baz` would
/// be represented by the environment variable `FOO_0_BAZ`.
class EnvironmentSource extends ConfigurationSource {
  /// Creates a [EnvironmentSource] from a map of environment variables.
  EnvironmentSource(Map<String, String> environment)
      : _environment = _normalizeEnvironment(environment);

  /// Creates a [EnvironmentSource] from [Platform.environment].
  factory EnvironmentSource.fromEnvironment() =>
      EnvironmentSource(Platform.environment);

  static Map<String, String> _normalizeEnvironment(
    Map<String, String> environment,
  ) =>
      environment.map((key, value) => MapEntry(key.toUpperCase(), value));

  static String _environmentVariableNameForKey(ConfigurationKey key) {
    final stringBuilder = StringBuffer();
    var isFirst = true;
    for (final segment in key.path) {
      if (segment is String) {
        if (!isFirst) {
          stringBuilder.write('_');
        }
        stringBuilder.write(segment.toUpperCase());
      } else {
        stringBuilder
          ..write('_')
          ..write(segment);
      }
      isFirst = false;
    }
    return stringBuilder.toString();
  }

  final Map<String, String> _environment;

  @override
  String get description => 'environment variables';

  @override
  String? operator [](ConfigurationKey key) =>
      _environment[_environmentVariableNameForKey(key)];

  @override
  bool contains(ConfigurationKey key) {
    final prefix = _environmentVariableNameForKey(key);
    return _environment.keys.any(
      (key) =>
          key.startsWith(prefix) &&
          // Prefix must end at a segment boundary.
          (key.length == prefix.length || key[prefix.length] == '_'),
    );
  }

  @override
  String describeKey(ConfigurationKey key) =>
      _environmentVariableNameForKey(key);
}

/// A [ConfigurationSource] that reads configuration values from a nested
/// structure of maps and lists.
///
/// The root of the structure must be a [Map]. All other values
/// must be of one of the following types:
///
/// - [Map]
/// - [List]
/// - [String]
/// - [bool]
/// - [num]
/// - [Null]
class DataSource extends ConfigurationSource {
  /// Creates a [DataSource] from a nested structure of maps and lists.
  ///
  /// The [description] is a human-readable description of the source of the
  /// data, for example, the path to a file.
  ///
  /// The root of [data] must be a [Map]. All other values
  /// must be of one of the following types:
  ///
  /// - [Map]
  /// - [List]
  /// - [String]
  /// - [bool]
  /// - [num]
  /// - [Null]
  DataSource({
    required this.description,
    required Map<Object?, Object?> data,
  }) : _data = data;

  static const _missing = Object();

  @override
  final String description;

  final Map<Object?, Object?> _data;

  @override
  String? operator [](ConfigurationKey key) {
    final value = _getValue(key);

    if (value == _missing || value == null || value is Map || value is List) {
      return null;
    }

    if (value is! String && value is! bool && value is! num) {
      throw StateError('The value of $key is not a String, bool, or num.');
    }

    return value.toString();
  }

  @override
  bool contains(ConfigurationKey key) => _getValue(key) != _missing;

  @override
  String describeKey(ConfigurationKey key) => key.toString();

  Object? _getValue(ConfigurationKey key) {
    Object? current = _data;
    for (final segment in key.path) {
      if (segment is String) {
        if (current is! Map) {
          return _missing;
        }
        if (!current.containsKey(segment)) {
          return _missing;
        }
        current = current[segment];
      } else {
        if (current is! List) {
          return _missing;
        }
        final index = segment as int;
        if (current.length <= index) {
          return _missing;
        }
        current = current[index];
      }
      if (current == null) {
        return null;
      }
    }

    return current;
  }
}

/// A [ConfigurationSource] that reads configuration values from a list of
/// command-line arguments.
///
/// The arguments must be in the form `--key=value` or `--key value`. Arguments
/// that do not start with `--` are ignored. For example, given the arguments
/// `['--foo[0].bar', 'baz']`, looking up the key `foo[0].bar` would return
/// the value `"baz"`.
class CommandLineSource extends ConfigurationSource {
  /// Creates a [CommandLineSource] from a list of command-line arguments.
  ///
  /// The arguments must be in the form `--key=value` or `--key value`.
  /// Arguments that do not start with `--` are ignored.
  CommandLineSource(List<String> arguments)
      : _arguments = _parseArguments(arguments);

  static Map<String, String> _parseArguments(List<String> arguments) {
    final argumentsMap = <String, String>{};

    final iterator = arguments.iterator;
    while (iterator.moveNext()) {
      final argument = iterator.current;
      if (argument.startsWith('--')) {
        final parts = argument.split('=');
        final key = parts.removeAt(0).substring(2);
        var value = parts.isNotEmpty ? parts.join('=') : null;

        if (value == null) {
          if (iterator.moveNext()) {
            value = iterator.current;
          }
        }

        if (value != null) {
          argumentsMap[key] = value;
        }
      }
    }

    return argumentsMap;
  }

  final Map<String, String> _arguments;

  @override
  String get description => 'command line arguments';

  @override
  String? operator [](ConfigurationKey key) => _arguments[key.toString()];

  @override
  bool contains(ConfigurationKey key) {
    final prefix = key.toString();
    return _arguments.keys.any((key) =>
        key.startsWith(prefix) &&
        // Prefix must end at a segment boundary.
        (key.length == prefix.length ||
            key[prefix.length] == '.' ||
            key[prefix.length] == '['));
  }

  @override
  String describeKey(ConfigurationKey key) => '--$key';
}

/// Extension for reading a [ConfigurationSource] from a JSON string stored in
/// another [ConfigurationSource].
extension JsonConfExtension on ConfigurationSource {
  /// Loads a JSON string from this configuration` and returns a new
  /// [ConfigurationSource] containing the configuration values from the parsed
  /// JSON.
  ///
  /// The JSON string is read from the key `conf.json`. If the key is not
  /// present, `null` is returned.
  ConfigurationSource? loadJsonConf() {
    final key = ConfigurationKey(const ['conf', 'json']);
    final jsonString = this[key];
    if (jsonString == null) {
      return null;
    }

    Object? json;
    try {
      json = jsonDecode(jsonString);
    } on FormatException catch (e) {
      throw ConfigurationError(
        'Failed to parse JSON: ${e.message}',
        source: this,
        key: key,
      );
    }

    if (json is! Map<String, Object?>) {
      throw ConfigurationError(
        'Expected JSON value to be an object, but got ${json.runtimeType}.',
        source: this,
        key: key,
      );
    }

    return DataSource(
      description: describeKey(key),
      data: json,
    );
  }
}
