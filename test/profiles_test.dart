import 'package:conf/conf.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

enum TestProfile { a, b }

void main() {
  tearDown(() => Profiles.active = null);

  group('LoadProfilesExtension', () {
    test('from source', () async {
      final source = TestSource({'profiles': 'a,b'});
      await source.loadProfiles(allProfiles: TestProfile.values);
      expect(Profiles.active, equals({TestProfile.a, TestProfile.b}));
    });

    test('default profiles', () async {
      final source = TestSource({});
      await source.loadProfiles(
        allProfiles: TestProfile.values,
        defaultProfiles: {TestProfile.a},
      );
      expect(Profiles.active, equals({TestProfile.a}));
    });

    test('additional profiles', () async {
      final source = TestSource({'profiles': 'a'});
      await source.loadProfiles(
        allProfiles: TestProfile.values,
        additionalProfiles: {TestProfile.b},
      );
      expect(Profiles.active, equals({TestProfile.a, TestProfile.b}));
    });
  });
}
