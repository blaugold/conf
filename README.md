[![Version](https://badgen.net/pub/v/conf)](https://pub.dev/packages/conf)
[![CI](https://github.com/blaugold/conf/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/conf/actions/workflows/ci.yaml)

`conf` is a Dart package for defining configuration schemas and loading
configuration values from from multiple sources, such as:

- command line arguments
- environment variables
- JSON string from command line arguments or environment variables
- JSON files
- YAML files

Sources override each other in a configurable order.

## Installation

Add `conf` as a dependency in your `pubspec.yaml` file:

```shell
dart pub add conf
```

## Example

See the [example package](https://github.com/blaugold/conf/tree/main/example)
for a complete example.

## Schema

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

  factory DatabaseConfiguration._factory(Map<String, Object?> map) =>
      DatabaseConfiguration(
        url: map['url']! as Uri,
        username: map['username']! as String,
        password: map['password']! as String,
      );

  static final schema = ConfObject(
    propertiesMap: {
      'url': ConfUri(),
      'username': ConfString(),
      'password': ConfString(),
    },
    factory: DatabaseConfiguration._factory,
  );

  final Uri url;
  final String username;
  final String password;
}
```

Note that the `DatabaseConfiguration` class has a `schema` field that defines
the configuration schema for the class. The `schema` field is a `ConfObject`
that defines the configuration properties of the class and how to create an
instance of `DatabaseConfiguration` from a map of property values.

Now lets define a `ServerConfiguration` class that contains the
`DatabaseConfiguration` as well as the port and address to listen on:

```dart
class ServerConfiguration {
  ServerConfiguration({
    required this.port,
    required this.address,
    required this.database,
  });

  factory ServerConfiguration._factory(Map<String, Object?> map) =>
      ServerConfiguration(
        port: map['port']! as int,
        address: map['address']! as InternetAddress,
        database: map['database']! as DatabaseConfiguration,
      );

  static final schema = ConfObject(
    propertiesMap: {
      'port': ConfDefault(ConfInteger(), defaultValue: 8080),
      'address': ConfDefault(
        ConfInternetAddress(),
        defaultValue: InternetAddress.loopbackIPv4,
      ),
      'database': DatabaseConfiguration.schema,
    },
    factory: ServerConfiguration._factory,
  );

  final int port;
  final InternetAddress address;
  final DatabaseConfiguration database;
}
```

Here we use the `ConfDefault` class to define a default value for the `port` and
`address` properties. We also use the `DatabaseConfiguration.schema` field to
define the `database` property.

### Scalar values

`conf` provides a number of builtin schema classes to load scalar values:

- `ConfBool`
- `ConfNumber`
- `ConfInteger`
- `ConfDouble`
- `ConfString`
- `ConfDateTime`
- `ConfUri`
- `ConfInternetAddress`
- `ConfEnum`

You can also define your own scalar value schema classes by extending the
`ConfScalar` class, or one of its subclasses. For example, here is the
implementation of the `ConfInternetAddress` class:

```dart
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
```

## Loading configuration

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

try {
  final configuration = await ServerConfiguration.schema.load(source);
  // Do something with the configuration.
} on ConfigurationException catch (error) {
  stderr.writeln(error);
  exitCode = 1;
}
```

If loading the configuration fails, `load` throws a `ConfigurationException`.
`conf` does not stop after encountering the first error. Instead, it collects
all errors and makes them available in `ConfigurationException.errors`. This
allows you to display all errors at once, instead of fixing one error at a time.

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

## Configuration sources

A `ConfigurationSource` is a lower-level representation of configuration values
that makes it easy to load configuration values from different sources, such as:

- `CommandLineSource`: Loads configuration values from command line arguments.
- `EnvironmentSource`: Loads configuration values from environment variables.
- `DataSource`: Loads configuration values from a JSON-style data structure.
  Typically used to load configuration values from a JSON and YAML files.
- `CombiningSource`: Combines multiple sources into a single source.

### `AppSources`

`AppSources` provide an easy way to load configuration sources in an opinionated
way that is suitable for Dart applications, such as servers.

`AppSources` assumes that the application defines a set of profiles. A profile
is a named set of configuration values. For example, a server might have a `dev`
profile for development and a `prod` profile for production. Multiple profiles
can be active at the same time and are represented by the `Profiles` class.

```dart
enum Profile {
  dev,
  prod,
  test;

  /// The currently active profiles.
  static Profiles<Profile> get active => Profiles.active as Profiles<Profile>;
}
```

You specifying the active profiles as a comma separated list in the `--profiles`
command line argument or the `PROFILES` environment. For example:

```bash
$ dart run server.dart --profiles="dev,test"
```

Continuing with the example from the previous section, we can use
`AppSources.load` to load a `CombiningSource` that combines the command line and
environment sources as well as configuration file sources from a well-known
location.

```dart
class ServerConfiguration {

  // ...

  static Future<ServerConfiguration> load(
    List<String> arguments, {
    Set<Profile>? additionalProfiles,
  }) async {
    final sources = await AppSources.load(
      arguments: arguments,
      allProfiles: Profile.values,
      defaultProfiles: {Profile.dev},
      additionalProfiles: additionalProfiles,
    );
    return schema.load(sources);
  }

  // ...

}
```

After `AppSources.load` returns, `Profiles.active` contains the active profiles.

Configuration files are loaded from the following locations, in order or
precedence:

1. For each profile in alphabetical order:
   1. `config/application.$profile.json`
   2. `config/application.$profile.yaml`
   3. `config/application.$profile.yml`
2. The base configuration:
   1. `config/application.json`
   2. `config/application.yaml`
   3. `config/application.yml`

The paths are relative to the current working directory.

When multiple profiles are active, the precedence between profiles is determined
by sorting the profiles in alphabetical order. This is usually not something
that should be relied on. Instead profiles that are going to be activated
simultaneously should not have overlapping configuration values.

Profile configuration files always have a higher precedence than the base
configuration files.
