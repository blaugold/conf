import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';

import 'error.dart';
import 'source.dart';

/// A node in a configuration schema.
///
/// A configuration schema can load values of any type, such as [int], [bool]
/// or [DateTime], as well as composited types such as [List]s and custom
/// object types.
///
/// This is in contrast to the values that can be loaded directly from a
/// [ConfigurationSource], which only provides simple string values.
abstract class ConfigurationSchemaNode<T> {
  /// The parent node, or `null` if this is the root node.
  ConfigurationSchemaNode? get parent => _parent;
  ConfigurationSchemaNode? _parent;

  /// The children of this node.
  List<ConfigurationSchemaNode> get children => _children;
  final List<ConfigurationSchemaNode> _children = [];

  /// Loads the configuration value defined by this schema node at the [key]
  /// prefix from the given [source].
  ///
  /// Throws a [ConfigurationError] if the configuration value could not be
  /// loaded.
  Future<T> load(ConfigurationSource source, ConfigurationKey key);

  void _addChild(ConfigurationSchemaNode child) {
    if (_parent != null) {
      throw StateError(
        'ConfigurationNode has already been added to another parent node.',
      );
    }
    child._parent = this;
    _children.add(child);
  }
}

/// A configuration schema node that can [load] a value from a
/// [ConfigurationSource] without requiring a [ConfigurationKey].
abstract class RootSchemaNode<T> extends ConfigurationSchemaNode<T> {
  @override
  Future<T> load(ConfigurationSource source, [ConfigurationKey? key]);
}

abstract class _SingleChildConfigurationSchemaNode<C, T>
    extends ConfigurationSchemaNode<T> {
  _SingleChildConfigurationSchemaNode(ConfigurationSchemaNode<C> child) {
    _addChild(child);
  }

  ConfigurationSchemaNode<C> get child =>
      children.single as ConfigurationSchemaNode<C>;
}

abstract class _ProxyConfigurationSchemaNode<T>
    extends _SingleChildConfigurationSchemaNode<T, T> {
  _ProxyConfigurationSchemaNode(super.child);
}

/// A [ConfigurationSchemaNode] that loads a single value from it's string
/// representation.
abstract class ConfScalar<T> extends ConfigurationSchemaNode<T> {
  /// Creates a new scalar configuration schema node with the given [typeName].
  ConfScalar(this.typeName);

  /// The name of the type that this scalar loads.
  final String typeName;

  /// Loads a value of this scalar's type from the given [value].
  ///
  /// See the `[]` operator of [ConfigurationSource] for the possible types
  /// of [value].
  FutureOr<T> loadValue(Object? value);

  @override
  Future<T> load(ConfigurationSource source, ConfigurationKey? key) async {
    final value = source[key!];

    if (value == null && !source.contains(key)) {
      throw ConfigurationException([
        ConfigurationError(
          'Expected a value.',
          source: source,
          key: key,
        ),
      ]);
    }

    try {
      return await loadValue(value);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      throw ConfigurationException([
        ConfigurationError(error.toString(), source: source, key: key),
      ]);
    }
  }
}

/// A [ConfScalar] that loads a value from a string representation, if
/// the value is not already of the correct type.
abstract class ParseConfScalar<T> extends ConfScalar<T> {
  ParseConfScalar(super.typeName);

  /// Parses a value of this scalar's type from the given string [value].
  T parse(String value);

  @override
  T loadValue(Object? value) {
    if (value is T) {
      return value;
    }
    if (value is String) {
      return parse(value);
    }
    throw FormatException(
      'Cannot convert a value of type ${value.runtimeType} to $typeName.',
      value,
    );
  }
}

/// A [ParseConfScalar] that uses a function to parse values.
abstract class ParseFunctionConfScalar<T> extends ParseConfScalar<T> {
  /// Creates a new scalar configuration schema node with the given [typeName]
  /// and [_parse] function.
  ParseFunctionConfScalar(super.typeName, this._parse);

  final T Function(String value) _parse;

  @override
  T parse(String value) => _parse(value);
}

/// A [ConfScalar] that loads a [num] value.
class ConfNumber extends ParseFunctionConfScalar<num> {
  ConfNumber() : super('Number', num.parse);
}

/// A [ConfScalar] that loads an [int] value.
class ConfInteger extends ParseFunctionConfScalar<int> {
  ConfInteger() : super('Integer', int.parse);
}

/// A [ConfScalar] that loads a [double] value.
class ConfDouble extends ParseFunctionConfScalar<double> {
  ConfDouble() : super('Double', double.parse);
}

/// A [ConfScalar] that loads a [Uri] value.
class ConfUri extends ParseFunctionConfScalar<Uri> {
  ConfUri() : super('URI', Uri.parse);
}

/// A [ConfScalar] that loads a [DateTime] value.
class ConfDateTime extends ParseFunctionConfScalar<DateTime> {
  ConfDateTime() : super('DateTime', DateTime.parse);
}

/// A [ConfScalar] that loads a [String] value.
class ConfString extends ParseConfScalar<String> {
  ConfString() : super('String');

  @override
  String parse(String value) => value;
}

/// A [ConfScalar] that loads a [bool] value.
class ConfBoolean extends ParseConfScalar<bool> {
  ConfBoolean() : super('Boolean');

  @override
  bool parse(String value) {
    switch (value.toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        throw FormatException('Expected a boolean value but got "$value".');
    }
  }
}

/// A [ConfScalar] that loads an [InternetAddress] value.
class ConfInternetAddress extends ParseConfScalar<InternetAddress> {
  ConfInternetAddress() : super('InternetAddress');

  @override
  InternetAddress parse(String value) {
    final address = InternetAddress.tryParse(value);
    if (address == null) {
      throw FormatException(
        'Expected an IPv4 or IPv6 address but got "$value".',
      );
    }
    return address;
  }
}

/// A [ConfScalar] that loads an [Enum] value.
class ConfEnum<T extends Enum> extends ParseConfScalar<T> {
  ConfEnum(this.values) : super('Enum');

  /// The enum values that this scalar can load.
  final List<T> values;

  @override
  T parse(String value) {
    final enumValue =
        values.firstWhereOrNull((enumValue) => enumValue.name == value);

    if (enumValue == null) {
      final enumValues = values.map((value) => value.name).join(', ');
      throw FormatException(
        'Expected one of $enumValues but got "$value".',
      );
    }

    return enumValue;
  }
}

/// A [ConfigurationSchemaNode] that loads a configuration value if it exists,
/// or `null` if it doesn't.
class ConfNullable<T> extends _SingleChildConfigurationSchemaNode<T, T?> {
  ConfNullable(super.child);

  @override
  Future<T?> load(ConfigurationSource source, ConfigurationKey key) async {
    if (source.contains(key)) {
      return child.load(source, key);
    } else {
      return null;
    }
  }
}

/// A [ConfigurationSchemaNode] that loads a configuration value if it exists,
/// or a [defaultValue] if it doesn't.
class ConfDefault<T> extends _ProxyConfigurationSchemaNode<T> {
  ConfDefault(super.child, {required this.defaultValue});

  final T defaultValue;

  @override
  Future<T> load(ConfigurationSource source, ConfigurationKey key) async {
    if (source.contains(key)) {
      return child.load(source, key);
    } else {
      return defaultValue;
    }
  }
}

/// A [ConfigurationSchemaNode] that loads a configuration value from
/// a key that is calculated by appending a [base] key to the key that is
/// passed to [load].
class ConfRebase<T> extends _ProxyConfigurationSchemaNode<T>
    implements RootSchemaNode<T> {
  ConfRebase(this.base, super.child);

  /// The key to use as the base when loading the configuration value.
  final ConfigurationKey base;

  @override
  Future<T> load(ConfigurationSource source, [ConfigurationKey? key]) {
    final childKey = key != null ? key + base : base;
    return child.load(source, childKey);
  }
}

/// A [ConfigurationSchemaNode] that loads a list of configuration values.
class ConfList<T> extends _SingleChildConfigurationSchemaNode<T, List<T>> {
  /// Creates a new list configuration schema node with the given [child].
  ConfList(super.child);

  @override
  Future<List<T>> load(ConfigurationSource source, ConfigurationKey key) async {
    final list = <T>[];
    final errors = <ConfigurationError>[];

    Iterable<ConfigurationKey> elementKeys() sync* {
      for (var i = 0;; i++) {
        final elementKey = key + i;
        if (source.contains(elementKey)) {
          yield elementKey;
        } else {
          return;
        }
      }
    }

    await Future.wait(
      elementKeys().map((elementKey) async {
        await ConfigurationException.collectErrors(errors, () async {
          list.add(await child.load(source, elementKey));
        });
      }),
    );

    return errors.isEmpty ? list : throw ConfigurationException(errors);
  }
}

/// A function that creates the value of a [ConfObject] from a map of
/// property names to configuration values.
typedef ConfObjectFactory<T> = T Function(Map<String, Object?> properties);

/// A [ConfigurationSchemaNode] that loads a configuration value by composing
/// multiple configuration values into a single object.
class ConfObject<T> extends ConfigurationSchemaNode<T>
    implements RootSchemaNode<T> {
  /// Creates a new [ConfObject] with the given [properties].
  ///
  /// For convenience, the [propertiesMap] argument can be used to create
  /// properties from a map of property names to [ConfigurationSchemaNode]s.
  /// This is equivalent to creating a [ConfProperty] for each entry in the map,
  /// but does not require you to manually warp each [ConfigurationSchemaNode]
  /// in a [ConfProperty].
  ///
  /// The [factory] argument is used to create the a value of type [T]
  /// when loading an instance of this object. It is passed a map of property
  /// names to loaded configuration values.
  ConfObject({
    List<ConfProperty>? properties,
    Map<String, ConfigurationSchemaNode>? propertiesMap,
    required ConfObjectFactory<T> factory,
  }) : _factory = factory {
    [
      if (propertiesMap != null)
        for (final entry in propertiesMap.entries)
          ConfProperty(entry.key, entry.value),
      ...?properties,
    ].forEach(_addChild);
  }

  final ConfObjectFactory<T> _factory;

  /// The properties of this object.
  List<ConfProperty> get properties => _children.cast();

  @override
  Future<T> load(ConfigurationSource source, [ConfigurationKey? key]) async {
    final map = <String, Object?>{};
    final errors = <ConfigurationError>[];

    await Future.wait(
      properties.map((property) async {
        await ConfigurationException.collectErrors(errors, () async {
          map[property.name] = await property.load(source, key);
        });
      }),
    );

    return errors.isEmpty
        ? _factory(map)
        : throw ConfigurationException(errors);
  }

  @override
  void _addChild(covariant ConfProperty child) {
    if (properties.any((property) => property.name == child.name)) {
      throw ArgumentError.value(
        child,
        'child',
        'must have a unique name: ${child.name}',
      );
    }
    super._addChild(child);
  }
}

/// A [ConfigurationSchemaNode] that loads the configuration value for the
/// property of a [ConfObject].
class ConfProperty<T> extends ConfRebase<T> {
  ConfProperty(this.name, ConfigurationSchemaNode<T> child)
      : super(ConfigurationKey([name]), child);

  /// The name of this property.
  final String name;
}
