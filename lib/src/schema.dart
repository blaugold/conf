import 'dart:async';
import 'dart:io';

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
  /// If the value could be loaded successfully, the result will contain the
  /// value in [LoadConfigurationResult.value]. Otherwise, the result will
  /// contain all found configuration errors in
  /// [LoadConfigurationResult.errors].
  Future<LoadConfigurationResult<T>> load(
    ConfigurationSource source,
    ConfigurationKey key,
  );

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

/// The result of loading a configuration value from a configuration schema
/// through [ConfigurationSchemaNode.load].
class LoadConfigurationResult<T> {
  /// Creates a successful result with the given [value].
  LoadConfigurationResult.success(this.value) : errors = const [];

  /// Creates a failed result with the given [errors].
  LoadConfigurationResult.failure(this.errors) : value = null;

  /// The loaded value, or `null` if loading the value failed.
  final T? value;

  /// The errors that occurred while trying to load a value, or an empty list if
  /// loading a value succeeded.
  final List<ConfigurationError> errors;

  /// Whether loading a value failed.
  bool get hasErrors => errors.isNotEmpty;
}

/// A [ConfigurationSchemaNode] that loads a single value from it's string
/// representation.
abstract class ConfScalar<T> extends ConfigurationSchemaNode<T> {
  /// Creates a new scalar configuration schema node with the given [typeName].
  ConfScalar(this.typeName);

  /// The name of the type that this scalar loads.
  final String typeName;

  /// Loads a value of this scalar's type from the given string [value].
  FutureOr<T> loadValue(String value);

  @override
  Future<LoadConfigurationResult<T>> load(
    ConfigurationSource source,
    ConfigurationKey? key,
  ) async {
    final value = source[key!];

    if (value == null) {
      return LoadConfigurationResult.failure([
        ConfigurationError(
          'Expected a value.',
          source: source,
          key: key,
        ),
      ]);
    }

    try {
      return LoadConfigurationResult.success(await loadValue(value));
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return LoadConfigurationResult.failure([
        ConfigurationError(error.toString(), source: source, key: key),
      ]);
    }
  }
}

/// a [ConfScalar] that uses a provided function to load values.
abstract class FunctionConfScalar<T> extends ConfScalar<T> {
  /// Creates a new scalar configuration schema node with the given [typeName]
  /// and [_loadValue] function.
  FunctionConfScalar(super.typeName, this._loadValue);

  final T Function(String value) _loadValue;

  @override
  T loadValue(String value) => _loadValue(value);
}

/// A [ConfScalar] that loads a [num] value.
class ConfNumber extends FunctionConfScalar<num> {
  ConfNumber() : super('Number', num.parse);
}

/// A [ConfScalar] that loads an [int] value.
class ConfInteger extends FunctionConfScalar<int> {
  ConfInteger() : super('Integer', int.parse);
}

/// A [ConfScalar] that loads a [double] value.
class ConfDouble extends FunctionConfScalar<double> {
  ConfDouble() : super('Double', double.parse);
}

/// A [ConfScalar] that loads a [Uri] value.
class ConfUri extends FunctionConfScalar<Uri> {
  ConfUri() : super('URI', Uri.parse);
}

/// A [ConfScalar] that loads a [DateTime] value.
class ConfDateTime extends FunctionConfScalar<DateTime> {
  ConfDateTime() : super('DateTime', DateTime.parse);
}

/// A [ConfScalar] that loads a [String] value.
class ConfString extends ConfScalar<String> {
  ConfString() : super('String');

  @override
  String loadValue(String value) => value;
}

/// A [ConfScalar] that loads a [bool] value.
class ConfBoolean extends ConfScalar<bool> {
  ConfBoolean() : super('Boolean');

  @override
  bool loadValue(String value) {
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
class ConfInternetAddress extends ConfScalar<InternetAddress> {
  ConfInternetAddress() : super('InternetAddress');

  @override
  InternetAddress loadValue(String value) {
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
class ConfEnum<T extends Enum> extends ConfScalar<T> {
  ConfEnum(this.values) : super('Enum');

  /// The enum values that this scalar can load.
  final List<T> values;

  @override
  T loadValue(String value) {
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
  Future<LoadConfigurationResult<T?>> load(
    ConfigurationSource source,
    ConfigurationKey key,
  ) async {
    if (source.contains(key)) {
      return child.load(source, key);
    } else {
      return LoadConfigurationResult.success(null);
    }
  }
}

/// A [ConfigurationSchemaNode] that loads a configuration value if it exists,
/// or a [defaultValue] if it doesn't.
class ConfDefault<T> extends _ProxyConfigurationSchemaNode<T> {
  ConfDefault(super.child, {required this.defaultValue});

  final T defaultValue;

  @override
  Future<LoadConfigurationResult<T>> load(
    ConfigurationSource source,
    ConfigurationKey key,
  ) async {
    if (source.contains(key)) {
      return child.load(source, key);
    } else {
      return LoadConfigurationResult.success(defaultValue);
    }
  }
}

/// A [ConfigurationSchemaNode] that loads a configuration value from
/// a key that is calculated by appending a [base] key to the key that is
/// passed to [load].
class ConfRebase<T> extends _ProxyConfigurationSchemaNode<T> {
  ConfRebase(this.base, super.child);

  /// The key to use as the base when loading the configuration value.
  final ConfigurationKey base;

  @override
  Future<LoadConfigurationResult<T>> load(
    ConfigurationSource source, [
    ConfigurationKey? key,
  ]) {
    final childKey = key != null ? key + base : base;
    return child.load(source, childKey);
  }
}

/// A [ConfigurationSchemaNode] that loads a list of configuration values.
class ConfList<T> extends _SingleChildConfigurationSchemaNode<T, List<T>> {
  /// Creates a new list configuration schema node with the given [child].
  ConfList(super.child);

  @override
  Future<LoadConfigurationResult<List<T>>> load(
    ConfigurationSource source,
    ConfigurationKey key,
  ) async {
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

    await Future.wait(elementKeys().map((elementKey) async {
      final result = await child.load(source, elementKey);
      if (result.hasErrors) {
        errors.addAll(result.errors);
      } else {
        list.add(result.value as T);
      }
    }));

    return errors.isEmpty
        ? LoadConfigurationResult.success(list)
        : LoadConfigurationResult.failure(errors);
  }
}

/// A function that creates the value of a [ConfObject] from a map of
/// property names to configuration values.
typedef ConfObjectFactory<T> = T Function(Map<String, Object?> properties);

/// A [ConfigurationSchemaNode] that loads a configuration value by composing
/// multiple configuration values into a single object.
class ConfObject<T> extends ConfigurationSchemaNode<T> {
  /// Convenience constructor that creates a new [ConfObject]
  /// without having to create a [ConfProperty] for each property.
  ConfObject({
    required Map<String, ConfigurationSchemaNode> properties,
    required ConfObjectFactory<T> factory,
  }) : this.fromProperties(
          properties: {
            for (final entry in properties.entries)
              ConfProperty(entry.key, entry.value),
          },
          factory: factory,
        );

  /// Creates a new [ConfObject] with the given [properties] and [factory].
  ConfObject.fromProperties({
    required Iterable<ConfProperty> properties,
    required ConfObjectFactory<T> factory,
  }) : _factory = factory {
    properties.forEach(_addChild);
  }

  final ConfObjectFactory<T> _factory;

  /// The properties of this object.
  List<ConfProperty> get properties => _children.cast();

  @override
  Future<LoadConfigurationResult<T>> load(
    ConfigurationSource source, [
    ConfigurationKey? key,
  ]) async {
    final map = <String, Object?>{};
    final errors = <ConfigurationError>[];

    await Future.wait(properties.map((property) async {
      final result = await property.load(source, key);
      if (result.hasErrors) {
        errors.addAll(result.errors);
      } else {
        map[property.name] = result.value;
      }
    }));

    return errors.isEmpty
        ? LoadConfigurationResult.success(_factory(map))
        : LoadConfigurationResult.failure(errors);
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
