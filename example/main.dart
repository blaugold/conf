// ignore_for_file: avoid_print

import 'dart:io';

import 'package:conf/conf.dart';

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

Future<void> main() async {
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

  final config = result.value!;
  print('port: ${config.port}');
  print('address: ${config.address}');
  print('database.url: ${config.database.url}');
  print('database.username: ${config.database.username}');
  print('database.password: ${config.database.password}');
}
