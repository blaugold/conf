[![Version](https://badgen.net/pub/v/conf)](https://pub.dev/packages/conf)
[![CI](https://github.com/blaugold/conf/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/conf/actions/workflows/ci.yaml)

`conf` is a Dart package for defining configuration schemas and loading
configuration values from from multiple sources, such as:

- command line arguments
- environment variables
- JSON string from command line arguments or environment variables
- JSON files
- YAML files

Sources override each other in a specific order, that can be configured.

## Installation

Add `conf` as a dependency in your `pubspec.yaml` file:

```shell
dart pub add conf
```

## Usage

### Schema

Before you can load configuration values, you need to define a schema. I
recommend breaking your schema up into multiple classes, each of which holds
related configuration values. For example, if you have a server that needs to
connect to a database, you might define a `DatabaseConfiguration` class that
contains the database URL, username and password:

```dart
class DatabaseConfiguration {
  DatabaseConfiguration({
    required this.url,
    required this.username,
    required this.password,
  });

  factory DatabaseConfiguration.fromMap(Map<String, Object?> map) =>
      DatabaseConfiguration(
        url: map['url']! as Uri,
        username: map['username']! as String,
        password: map['password']! as String,
      );

  static final schema = ConfObject(
    properties: {
      'url': ConfUri(),
      'username': ConfString(),
      'password': ConfString(),
    },
    factory: DatabaseConfiguration.fromMap,
  );

  final Uri url;
  final String username;
  final String password;
}
```

Note that the `DatabaseConfiguration` class has a `schema` field that defines
the configuration schema for the class. The `schema` field is a `ConfObject`
that defines the configuration properties of the class and how to create the
class from a map of property values.

Now lets define a `ServerConfiguration` class that contains the
`DatabaseConfiguration` as well as the port and address to listen on:

```dart
class ServerConfiguration {
  ServerConfiguration({
    required this.port,
    required this.address,
    required this.database,
  });

  factory ServerConfiguration.fromMap(Map<String, Object?> map) =>
      ServerConfiguration(
        port: map['port']! as int,
        address: map['address']! as InternetAddress,
        database: map['database']! as DatabaseConfiguration,
      );

  static final schema = ConfObject(
    properties: {
      'port': ConfDefault(ConfInteger(), defaultValue: 8080),
      'address': ConfDefault(
        ConfInternetAddress(),
        defaultValue: InternetAddress.loopbackIPv4,
      ),
      'database': DatabaseConfiguration.schema,
    },
    factory: ServerConfiguration.fromMap,
  );

  final int port;
  final InternetAddress address;
  final DatabaseConfiguration database;
}
```

Here we use the `ConfDefault` class to define a default value for the `port` and
`address` properties. We also use the `DatabaseConfiguration.schema` field to
define the `database` property.

#### Scalar values

`conf` provides a number of builtin schema classes to load scalar values:

- `ConfBool`
- `ConfNumber`
- `ConfInteger`
- `ConfDouble`
- `ConfString`
- `ConfDateTime`
- `ConfUri`
- `ConfInternetAddress`

You can also define your own scalar value schema classes by extending the
`ConfScalar` class. For example, here is the implementation of the
`ConfInternetAddress` class:

```dart
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
```

### Loading configuration values

To load the `ServerConfiguration` we need a `ConfigurationSource` that provides
the configuration values. For simplicity, we'll provide the configuration values
directly in code:

```dart
final source = CombiningSource([
  CommandLineSource(['--database.username=test']),
  EnvironmentSource({
    'PORT': '4567',
    'DATABASE_URL': 'postgres://localhost:5432/db',
    'DATABASE_USERNAME': 'dev',
    'DATABASE_PASSWORD': 'password',
  })
]);

final result = await ServerConfiguration.schema.load(source);
if (result.hasErrors) {
  print('Configuration is invalid:');
  print(result.errors.join('\n'));
  exit(1);
}

final config = result.value;
```

`conf` does not stop after the first error. Instead, it collects all errors and
returns them in the `LoadConfigurationResult.errors` field. This allows you to
display all errors at once, instead of fixing one error at a time.

The example above demonstrates one of the core features of `conf`: The ability
to load configuration values from multiples sources, which have different
formats.

`conf` inferred a environment variable name from the schema for each
configuration value. For example, the `port` property is loaded from the `PORT`
environment variable and the `database.url` property is loaded from the
`DATABASE_URL`.

Formatting of configuration values from the command line is slightly different.
For example, the `database.username` property is loaded from the
`--database.username` command line argument.

Because we specified the `CommandLineSource` first, the `database.username`
property is loaded from the command line argument instead of the environment
variable.

### Configuration sources

A `ConfigurationSource` is a lower-level representation of configuration values
that makes it easy to load configuration values from different sources, such as:

- `CommandLineSource`: Loads configuration values from command line arguments.
- `EnvironmentSource`: Loads configuration values from environment variables.
- `DataSource`: Loads configuration values from a JSON-style data structure.
  Typically used to load configuration values from a JSON and YAML files.
- `CombiningSource`: Combines multiple sources into a single source.
