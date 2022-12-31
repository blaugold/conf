import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';

import 'schema.dart';
import 'source.dart';

/// A set of configuration profiles.
///
/// A configuration profile is an enum value in a user defined enum (typically
/// named `Profile`):
///
/// ```dart
/// enum Profile {
///  dev,
///  prod,
///  test;
///
///  static Profiles<Profile> get active =>
///     Profiles.active as Profiles<Profile>;
/// }
/// ```
///
/// A [Profiles] object is typically used to represent the set of currently
/// active configuration profiles. The currently active [Profiles] object can be
/// accessed via the [active] getter and setter.
///
/// A [Profiles] object is immutable.
///
/// See also:
///
/// - [LoadProfilesExtension] for loading configuration profiles from a
///   [ConfigurationSource].
class Profiles<T extends Enum> extends SetBase<T> {
  /// Creates a [Profiles] object from a set of profiles.
  ///
  /// If [profiles] is already a [Profiles] object, it is returned as-is.
  factory Profiles(Set<T> profiles) {
    if (profiles is Profiles<T>) {
      return profiles;
    }
    return Profiles._(profiles);
  }

  Profiles._(this._profiles);

  static Profiles? _active;

  /// The [Profiles] object that contains the currently active profiles.
  static Profiles get active {
    if (_active == null) {
      throw StateError('No active profiles have been set.');
    }
    return _active!;
  }

  static set active(Profiles? value) {
    _active = value;
  }

  final Set<T> _profiles;

  @override
  int get length => _profiles.length;

  @override
  Iterator<T> get iterator => _profiles.iterator;

  @override
  bool contains(Object? element) => _profiles.contains(element);

  @override
  T? lookup(Object? element) => _profiles.lookup(element);

  @override
  Set<T> toSet() => _profiles.toSet();

  @override
  bool add(T value) => throw UnsupportedError('Profiles are immutable.');

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('Profiles are immutable.');

  @override
  String toString() =>
      '{${_profiles.map((profile) => profile.name).join(', ')}}';
}

/// A [ConfScalar] that loads a [Profiles] object.
class ConfProfiles<T extends Enum> extends ParseConfScalar<Profiles<T>> {
  ConfProfiles(this.profiles) : super('Profiles');

  final List<T> profiles;

  @override
  Profiles<T> parse(String value) => Profiles(_parseProfilesListString(value));

  Set<T> _parseProfilesListString(String value) =>
      value.split(',').map(_parseProfile).toSet();

  T _parseProfile(String value) {
    // ignore: parameter_assignments
    value = value.trim();

    final profile =
        profiles.firstWhereOrNull((profile) => profile.name == value);
    if (profile == null) {
      final profilesList = profiles.map((profile) => profile.name).join(', ');
      throw FormatException(
        'Expected one of $profilesList, but got "$value".',
      );
    }
    return profile;
  }
}

/// A [ConfProperty] that loads a [Profiles] object from the "profiles"
/// configuration value.
///
/// [allProfiles] is the list of all possible profiles.
///
/// [defaultProfiles] is the list of profiles to use if the "profiles"
/// configuration value is not set.
ConfProperty<Profiles<T>> profilesProperty<T extends Enum>({
  required List<T> allProfiles,
  Set<T> defaultProfiles = const {},
}) =>
    ConfProperty(
      'profiles',
      ConfDefault(
        ConfProfiles(allProfiles),
        defaultValue: Profiles(defaultProfiles),
      ),
    );

/// An extension for loading and activating a set of [Profiles] from
/// a [ConfigurationSource].
extension LoadProfilesExtension on ConfigurationSource {
  /// Loads a set of [Profiles] from this source and sets [Profiles.active] to
  /// the loaded profiles.
  ///
  /// [allProfiles] is the list of all possible profiles.
  ///
  /// [defaultProfiles] is the list of profiles to use if the "profiles"
  /// configuration value is not set.
  ///
  /// [additionalProfiles] is an optional set of additional profiles to add to
  /// the loaded profiles.
  Future<Profiles<T>> loadProfiles<T extends Enum>({
    required List<T> allProfiles,
    Set<T> defaultProfiles = const {},
    Set<T>? additionalProfiles,
  }) async {
    final profilesFromSource = await profilesProperty(
      allProfiles: allProfiles,
      defaultProfiles: defaultProfiles,
    ).load(this);

    final profiles = Profiles({
      ...profilesFromSource,
      if (additionalProfiles != null) ...additionalProfiles,
    });

    Profiles.active = profiles;
    return profiles;
  }
}
