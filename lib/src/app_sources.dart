import 'dart:async';
import 'dart:io';

import 'file.dart';
import 'profiles.dart';
import 'source.dart';

/// Opinionated loading of configuration sources for a Dart applications, such
/// as servers.
///
/// See [load] for more details.
extension AppSources on CombiningSource {
  /// Load configuration sources for a Dart application in an opinionated way.
  ///
  /// Configuration sources are loaded in the following order:
  ///
  /// 1. --conf.json command line argument
  /// 2. Command line arguments
  /// 3. CONF_JSON environment variable
  /// 4. Environment variables
  /// 5. Configuration files in `config` directory:
  ///    1. For each profile in alphabetical order:
  ///       1. `application.$profile.json`
  ///       2. `application.$profile.yaml`
  ///       3. `application.$profile.yml`
  ///    2. The base configuration:
  ///       1. `application.json`
  ///       2. `application.yaml`
  ///       3. `application.yml`
  static Future<ConfigurationSource> load<P extends Enum>({
    List<String>? arguments,
    Map<String, String>? environment,
    required List<P> allProfiles,
    Set<P> defaultProfiles = const {},
    Set<P>? additionalProfiles,
  }) async {
    final sources = CombiningSource();
    sources.addDynamicSources(
      arguments: arguments,
      environment: environment,
    );
    final profiles = await sources.loadProfiles(
      allProfiles: allProfiles,
      defaultProfiles: defaultProfiles,
      additionalProfiles: additionalProfiles,
    );
    await sources.addStaticSources(profiles: profiles);
    return sources;
  }

  /// Add configuration sources that are dynamic, such as command line arguments
  /// and environment variables to this [CombiningSource].
  void addDynamicSources({
    List<String>? arguments,
    Map<String, String>? environment,
  }) {
    final commandLineSource =
        arguments != null ? CommandLineSource(arguments) : null;
    final environmentSource =
        EnvironmentSource(environment ?? Platform.environment);

    final commandLineJsonSource = commandLineSource?.loadJsonConf();
    final environmentJsonSource = environmentSource.loadJsonConf();

    return addAll([
      if (commandLineJsonSource != null) commandLineJsonSource,
      if (commandLineSource != null) commandLineSource,
      if (environmentJsonSource != null) environmentJsonSource,
      environmentSource,
    ]);
  }

  /// Add configuration sources that are static, such as configuration files to
  /// this [CombiningSource].
  Future<void> addStaticSources<P extends Enum>({
    required Profiles profiles,
  }) async {
    addAll(
      await loadConfigurationFiles(
        directory: 'config',
        configName: 'application',
        variants: profiles.map((profile) => profile.name).toList()..sort(),
      ),
    );
  }
}
