import 'package:conf/conf.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ConfigurationKey', () {
    test('throws if path is empty', () {
      expect(() => ConfigurationKey(const []), throwsArgumentError);
    });

    test('throws if path contains empty string', () {
      expect(() => ConfigurationKey(const ['']), throwsArgumentError);
    });

    test('throws if path contains string containing "."', () {
      expect(() => ConfigurationKey(const ['.']), throwsArgumentError);
    });

    test('throws if path contains unsupported types', () {
      expect(() => ConfigurationKey(const [.0]), throwsArgumentError);
    });

    test('concat', () {
      expect(keyA + 'b', equals(ConfigurationKey(const ['a', 'b'])));
      expect(keyA + 0, equals(ConfigurationKey(const ['a', 0])));
      expect(keyA + keyA, equals(ConfigurationKey(const ['a', 'a'])));
    });

    test('compare keys', () {
      expect(keyA, equals(keyA));
      expect(keyA, equals(ConfigurationKey(const ['a'])));
      expect(keyA, isNot(equals(ConfigurationKey(const ['b']))));
      expect(keyA.hashCode, equals(keyA.hashCode));
      expect(keyA.hashCode, equals(ConfigurationKey(const ['a']).hashCode));
      expect(
        keyA.hashCode,
        isNot(equals(ConfigurationKey(const ['b']).hashCode)),
      );
    });

    test('toString', () {
      expect(keyA.toString(), equals('a'));
      expect((keyA + 'b').toString(), equals('a.b'));
      expect((keyA + 0).toString(), equals('a[0]'));
      expect((keyA + 0 + 'b').toString(), equals('a[0].b'));
    });
  });

  group('CombiningSource', () {
    test('no sources', () async {
      final source = CombiningSource([]);
      expect(source[keyA], isNull);
      expect(source.contains(keyA), isFalse);
      expect(source.describeKey(keyA), keyA.toString());
    });

    test('single source', () async {
      final source = CombiningSource([
        TestSource({'a': 'b'})
      ]);
      expect(source[keyA], equals('b'));
      expect(source.contains(keyA), isTrue);
      expect(source.describeKey(keyA), 'a from test source');
    });

    test('first source shadows second source', () async {
      final source = CombiningSource([
        TestSource({'a': 'b'}, 'first'),
        TestSource({'a': 'c'}, 'second'),
      ]);
      expect(source[keyA], equals('b'));
      expect(source.contains(keyA), isTrue);
      expect(source.describeKey(keyA), 'a from first');
    });

    test('finds value in second source', () async {
      final source = CombiningSource([
        TestSource({}, 'first'),
        TestSource({'a': 'b'}, 'second'),
      ]);
      expect(source[keyA], equals('b'));
      expect(source.contains(keyA), isTrue);
      expect(source.describeKey(keyA), 'a from second');
    });
  });

  group('EnvironmentSource', () {
    test('get values', () {
      final source = EnvironmentSource({
        'a': 'b',
        'C': 'd',
      });
      expect(source[ConfigurationKey(const ['a'])], equals('b'));
      expect(source[ConfigurationKey(const ['A'])], equals('b'));
      expect(source[ConfigurationKey(const ['c'])], equals('d'));
      expect(source[ConfigurationKey(const ['C'])], equals('d'));
    });

    test('contains', () {
      final source = EnvironmentSource({
        'A': 'b',
        'A_0': 'b',
        'A_A': 'c',
        'B_BB': 'c',
      });
      expect(source.contains(ConfigurationKey(const ['a'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['A'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['a', 0])), isTrue);
      expect(source.contains(ConfigurationKey(const ['a', 1])), isFalse);
      expect(source.contains(ConfigurationKey(const ['a', 'a'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b', 'bb'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b', 'b'])), isFalse);
      expect(source.contains(ConfigurationKey(const ['x'])), isFalse);
    });

    test('describeKey', () {
      final source = EnvironmentSource({});
      expect(source.describeKey(ConfigurationKey(const ['a'])), 'A');
      expect(source.describeKey(ConfigurationKey(const ['A'])), 'A');
      expect(source.describeKey(ConfigurationKey(const ['a', 0])), 'A_0');
      expect(source.describeKey(ConfigurationKey(const ['a', 'b'])), 'A_B');
    });
  });

  group('DataSource', () {
    test('get values', () {
      final source = TestSource({
        'a': true,
        'b': {
          'c': 0,
        },
        'd': [null, 'e', .0],
      });
      expect(source[ConfigurationKey(const ['a'])], equals('true'));
      expect(source[ConfigurationKey(const ['b'])], isNull);
      expect(source[ConfigurationKey(const ['b', 'c'])], equals('0'));
      expect(source[ConfigurationKey(const ['b', 'x'])], isNull);
      expect(source[ConfigurationKey(const ['d'])], isNull);
      expect(source[ConfigurationKey(const ['d', 0])], isNull);
      expect(source[ConfigurationKey(const ['d', 1])], equals('e'));
      expect(source[ConfigurationKey(const ['d', 2])], equals('0.0'));
      expect(source[ConfigurationKey(const ['d', 3])], isNull);
      expect(source[ConfigurationKey(const ['x'])], isNull);
    });

    test('contains', () {
      final source = TestSource({
        'a': true,
        'b': {
          'c': 0,
        },
        'd': [null, 'e', .0],
      });
      expect(source.contains(ConfigurationKey(const ['a'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b', 'c'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b', 'x'])), isFalse);
      expect(source.contains(ConfigurationKey(const ['d'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 0])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 1])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 2])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 3])), isFalse);
      expect(source.contains(ConfigurationKey(const ['x'])), isFalse);
    });

    test('describeKey', () {
      final source = TestSource({});
      expect(source.describeKey(ConfigurationKey(const ['a'])), 'a');
      expect(source.describeKey(ConfigurationKey(const ['a', 0])), 'a[0]');
      expect(source.describeKey(ConfigurationKey(const ['a', 'b'])), 'a.b');
    });
  });

  group('CommandLineSource', () {
    test('get values', () {
      final source = CommandLineSource([
        '--a=b',
        '--c',
        'd',
        '--d.e=f',
        '--d[0]=g',
      ]);
      expect(source[ConfigurationKey(const ['a'])], equals('b'));
      expect(source[ConfigurationKey(const ['c'])], equals('d'));
      expect(source[ConfigurationKey(const ['d', 'e'])], equals('f'));
      expect(source[ConfigurationKey(const ['d', 0])], equals('g'));
      expect(source[ConfigurationKey(const ['x'])], isNull);
    });

    test('contains', () {
      final source = CommandLineSource([
        '--a=true',
        '--b.c=0',
        '--d[0]=null',
        '--d[1]=e',
        '--d[2]=0.0',
        '--f.ff=true',
        '--f.fff.f=true',
        '--f.ffff[0]=true',
      ]);
      expect(source.contains(ConfigurationKey(const ['a'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b', 'c'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['b', 'x'])), isFalse);
      expect(source.contains(ConfigurationKey(const ['d'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 0])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 1])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 2])), isTrue);
      expect(source.contains(ConfigurationKey(const ['d', 3])), isFalse);
      expect(source.contains(ConfigurationKey(const ['f', 'f'])), isFalse);
      expect(source.contains(ConfigurationKey(const ['f', 'ff'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['f', 'fff'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['f', 'ffff'])), isTrue);
      expect(source.contains(ConfigurationKey(const ['x'])), isFalse);
    });

    test('describeKey', () {
      final source = CommandLineSource([]);
      expect(source.describeKey(ConfigurationKey(const ['a'])), '--a');
      expect(source.describeKey(ConfigurationKey(const ['a', 0])), '--a[0]');
      expect(source.describeKey(ConfigurationKey(const ['a', 'b'])), '--a.b');
    });
  });
}
