import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'error.dart';
import 'source.dart';

/// Loads a set of configuration files and returns a list of [DataSource]s
/// containing the loaded configuration values.
///
/// This function constructs a list of file paths to try to load, based on the
/// [configName] and [variants] parameters and supported extensions
/// (.json, .yaml, .yml). For each file path that exists, it loads the file and
/// includes a [DataSource] in the returned list.
///
/// The following file paths are tried, in order:
///
/// * `$directory/$configName.$variant.json`
/// * `$directory/$configName.$variant.yaml`
/// * `$directory/$configName.$variant.yml`
/// * `$directory/$configName.json`
/// * `$directory/$configName.yaml`
/// * `$directory/$configName.yml`
///
/// The returned list of [DataSource]s is sorted in the same order as the
/// file paths that were tried.
Future<List<ConfigurationSource>> loadConfigurationFiles({
  required String directory,
  required String configName,
  List<String>? variants,
}) async {
  final baseFilePath = path.join(directory, configName);

  final filePaths = [
    ...?variants?.map((profile) => '$baseFilePath.$profile'),
    baseFilePath,
  ]
      .expand((filePath) => [
            '$filePath.json',
            '$filePath.yaml',
            '$filePath.yml',
          ])
      .where((filePath) => File(filePath).existsSync());

  return Future.wait(filePaths.map(loadConfigurationFile));
}

/// Loads a configuration file and returns a [ConfigurationSource] containing
/// the parsed data.
///
/// The file extension determines the format of the file. Currently, only JSON
/// and YAML files are supported.
///
/// See also:
///
/// * [loadJsonConfigurationFile], which loads a JSON configuration file.
/// * [loadYamlConfigurationFile], which loads a YAML configuration file.
Future<DataSource> loadConfigurationFile(String filePath) async {
  switch (path.extension(filePath)) {
    case '.json':
      return loadJsonConfigurationFile(filePath);
    case '.yaml':
    case '.yml':
      return loadYamlConfigurationFile(filePath);
    default:
      throw ConfigurationError(
        'Unsupported configuration file extension: '
        '"${path.canonicalize(filePath)}".',
      );
  }
}

/// Loads a JSON configuration file and returns a [DataSource] containing the
/// parsed JSON data.
///
/// See also:
///
/// * [loadConfigurationFile], which loads a configuration file of any supported
///   format.
/// * [loadYamlConfigurationFile], which loads a YAML configuration file.
Future<DataSource> loadJsonConfigurationFile(String filePath) async {
  final file = File(filePath);

  Object? json;
  try {
    json = jsonDecode(await file.readAsString());
  } on FormatException catch (error) {
    throw ConfigurationError(
      'Failed to parse file "${path.canonicalize(filePath)}" as JSON: '
      '${error.message}',
    );
  }

  if (json is! Map<String, Object?>) {
    throw ConfigurationError(
      'Expected top level JSON value in file "${path.canonicalize(filePath)}" '
      'to be an object, but got ${json.runtimeType}.',
    );
  }

  return DataSource(
    description: file.absolute.path,
    data: json,
  );
}

/// Loads a YAML configuration file and returns a [DataSource] containing the
/// parsed YAML data.
///
/// See also:
///
/// * [loadConfigurationFile], which loads a configuration file of any supported
///   format.
/// * [loadJsonConfigurationFile], which loads a JSON configuration file.
Future<DataSource> loadYamlConfigurationFile(String filePath) async {
  final file = File(filePath);

  Object? yaml;
  try {
    yaml = loadYaml(await file.readAsString(), sourceUrl: file.absolute.uri);
  } on YamlException catch (e) {
    throw ConfigurationError(
      'Failed to parse file "${path.canonicalize(filePath)}" as YAML: '
      '${e.message}',
    );
  }

  if (yaml is! Map) {
    throw ConfigurationError(
      'Expected top level YAML value in file "${path.canonicalize(filePath)}" '
      'to be an object, but got ${yaml.runtimeType}.',
    );
  }

  return DataSource(
    description: file.absolute.path,
    data: yaml,
  );
}
