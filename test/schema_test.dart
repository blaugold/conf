import 'dart:io';

import 'package:conf/conf.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ConfScalar', () {
    test('reports error when value is missing', () async {
      final source = TestSource({});
      final scalar = ConfString();
      expect(
        scalar.load(source, keyA),
        throwsA(
          configurationException([
            configurationError(
              'Expected a value.',
              source: source,
              key: keyA,
            )
          ]),
        ),
      );
    });

    test('reports error when value is invalid', () async {
      final source = TestSource({'a': 'b'});
      final scalar = ConfBoolean();
      expect(
        scalar.load(source, keyA),
        throwsA(
          configurationException([
            configurationError(
              'FormatException: Expected a boolean value but got "b".',
              source: source,
              key: keyA,
            )
          ]),
        ),
      );
    });

    group('builtin scalar types', () {
      test('with string values', () async {
        final source = TestSource({
          'string': 'a',
          'boolean': 'true',
          'number': '1',
          'integer': '1',
          'float': '1.0',
          'uri': 'https://example.com',
          'dateTime': '2021-01-01T00:00:00.000Z',
          'internetAddress': '127.0.0.1',
          'testEnum': 'a'
        });
        final value = await BuiltinScalarsObject.schema.load(source);
        expect(value.string, equals('a'));
        expect(value.boolean, isTrue);
        expect(value.number, equals(1));
        expect(value.integer, equals(1));
        expect(value.float, equals(1.0));
        expect(value.uri, equals(Uri.parse('https://example.com')));
        expect(
          value.dateTime,
          equals(DateTime.parse('2021-01-01T00:00:00.000Z')),
        );
        expect(value.internetAddress, equals(InternetAddress.loopbackIPv4));
        expect(value.testEnum, equals(TestEnum.a));
      });

      test('with scalar target type values', () async {
        final source = TestSource({
          'string': 'a',
          'boolean': true,
          'number': 1,
          'integer': 1,
          'float': 1.0,
          'uri': Uri.parse('https://example.com'),
          'dateTime': DateTime.parse('2021-01-01T00:00:00.000Z'),
          'internetAddress': InternetAddress.tryParse('127.0.0.1'),
          'testEnum': TestEnum.a,
        });
        final value = await BuiltinScalarsObject.schema.load(source);
        expect(value.string, equals('a'));
        expect(value.boolean, isTrue);
        expect(value.number, equals(1));
        expect(value.integer, equals(1));
        expect(value.float, equals(1.0));
        expect(value.uri, equals(Uri.parse('https://example.com')));
        expect(
          value.dateTime,
          equals(DateTime.parse('2021-01-01T00:00:00.000Z')),
        );
        expect(value.internetAddress, equals(InternetAddress.loopbackIPv4));
        expect(value.testEnum, equals(TestEnum.a));
      });
    });
  });

  test('ConfNullable', () async {
    final source = TestSource({'a': 'true'});
    final scalar = ConfNullable(ConfBoolean());
    var value = await scalar.load(source, keyA);
    expect(value, isTrue);
    value = await scalar.load(source, ConfigurationKey(const ['b']));
    expect(value, isNull);
  });

  test('ConfDefault', () async {
    final source = TestSource({'a': 'true'});
    final scalar = ConfDefault(ConfBoolean(), defaultValue: false);
    var value = await scalar.load(source, keyA);
    expect(value, isTrue);
    value = await scalar.load(source, ConfigurationKey(const ['b']));
    expect(value, isFalse);
  });

  group('ConfList', () {
    test('reports errors from child values', () async {
      final source = TestSource({
        'a': ['a']
      });
      final list = ConfList(ConfBoolean());
      expect(
        list.load(source, keyA),
        throwsA(
          configurationException([
            configurationError(
              'FormatException: Expected a boolean value but got "a".',
              source: source,
              key: keyA + 0,
            )
          ]),
        ),
      );
    });

    test('empty list', () async {
      final source = TestSource({'a': []});
      final list = ConfList(ConfString());
      final value = await list.load(source, keyA);
      expect(value, isEmpty);
    });

    test('1 element list', () async {
      final source = TestSource({
        'a': ['a']
      });
      final list = ConfList(ConfString());
      final value = await list.load(source, keyA);
      expect(value, equals(['a']));
    });

    test('3 element list', () async {
      final source = TestSource({
        'a': ['a', 'b', 'c']
      });
      final list = ConfList(ConfString());
      final value = await list.load(source, keyA);
      expect(value, equals(['a', 'b', 'c']));
    });
  });

  group('ConfObject', () {
    test('reports errors from child values', () async {
      final source = TestSource({'a': 'a'});
      final object = ConfObject(
        propertiesMap: {'a': ConfBoolean()},
        factory: (map) => map,
      );
      expect(
        object.load(source),
        throwsA(
          configurationException([
            configurationError(
              'FormatException: Expected a boolean value but got "a".',
              source: source,
              key: keyA,
            )
          ]),
        ),
      );
    });

    test('throws when property names are not unique', () {
      expect(
        () => ConfObject(
          properties: [
            ConfProperty('a', ConfString()),
            ConfProperty('a', ConfString()),
          ],
          factory: (map) => map,
        ),
        throwsArgumentError,
      );
    });

    test('empty object', () async {
      final source = TestSource({});
      final object = ConfObject(propertiesMap: {}, factory: (map) => map);
      final value = await object.load(source);
      expect(value, equals({}));
    });

    test('1 property object', () async {
      final source = TestSource({'a': 'a'});
      final object =
          ConfObject(propertiesMap: {'a': ConfString()}, factory: (map) => map);
      final value = await object.load(source);
      expect(value, equals({'a': 'a'}));
    });
  });
}

enum TestEnum { a, b }

class BuiltinScalarsObject {
  BuiltinScalarsObject({
    required this.string,
    required this.boolean,
    required this.number,
    required this.integer,
    required this.float,
    required this.uri,
    required this.dateTime,
    required this.internetAddress,
    required this.testEnum,
  });

  factory BuiltinScalarsObject._factory(Map<String, Object?> json) =>
      BuiltinScalarsObject(
        string: json['string']! as String,
        boolean: json['boolean']! as bool,
        number: json['number']! as num,
        integer: json['integer']! as int,
        float: json['float']! as double,
        uri: json['uri']! as Uri,
        dateTime: json['dateTime']! as DateTime,
        internetAddress: json['internetAddress']! as InternetAddress,
        testEnum: json['testEnum']! as TestEnum,
      );

  static final schema = ConfObject(
    propertiesMap: {
      'string': ConfString(),
      'boolean': ConfBoolean(),
      'number': ConfNumber(),
      'integer': ConfInteger(),
      'float': ConfDouble(),
      'uri': ConfUri(),
      'dateTime': ConfDateTime(),
      'internetAddress': ConfInternetAddress(),
      'testEnum': ConfEnum(TestEnum.values),
    },
    factory: BuiltinScalarsObject._factory,
  );

  final String string;
  final bool boolean;
  final num number;
  final int integer;
  final double float;
  final Uri uri;
  final DateTime dateTime;
  final InternetAddress internetAddress;
  final TestEnum testEnum;
}
