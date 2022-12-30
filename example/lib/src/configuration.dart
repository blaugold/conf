// ignore_for_file: avoid_print

import 'dart:io';

import 'package:conf/conf.dart';

import 'error.dart';

enum Profile {
  dev,
  prod,
  test;

  static Profiles<Profile> get active => Profiles.active as Profiles<Profile>;
}

class ServerConfiguration {
  ServerConfiguration({
    required this.port,
    required this.address,
    required this.logRequests,
    required this.database,
  });

  factory ServerConfiguration._factory(Map<String, Object?> map) =>
      ServerConfiguration(
        port: map['port']! as int,
        address: map['address']! as InternetAddress,
        logRequests: map['logRequests']! as bool,
        database: map['database']! as DatabaseConfiguration,
      );

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

    final result = await schema.load(sources);
    if (result.hasErrors) {
      print('Could not load configuration:');
      print('');
      var i = 1;
      for (final error in result.errors) {
        print('${i++}. ${error.description}');
      }
      throw FatalException();
    }

    return result.value!;
  }

  static final schema = ConfObject(
    propertiesMap: {
      'port': ConfDefault(ConfInteger(), defaultValue: 8080),
      'address': ConfDefault(
        ConfInternetAddress(),
        defaultValue: InternetAddress.loopbackIPv4,
      ),
      'logRequests': ConfBoolean(),
      'database': DatabaseConfiguration.schema,
    },
    factory: ServerConfiguration._factory,
  );

  final int port;
  final InternetAddress address;
  final bool logRequests;
  final DatabaseConfiguration database;

  Map<String, Object?> toJson() => {
        'port': port,
        'address': address.address,
        'logRequests': logRequests,
        'database': database.toJson(),
      };
}

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
    propertiesMap: {
      'url': ConfUri(),
      'username': ConfString(),
      'password': ConfString(),
    },
    factory: DatabaseConfiguration.fromMap,
  );

  final Uri url;
  final String username;
  final String password;

  Map<String, Object?> toJson() => {
        'url': url.toString(),
        'username': username,
        'password': password,
      };
}
