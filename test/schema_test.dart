import 'dart:io';

import 'package:conf/conf.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ConfScalar', () {
    test('reports error when value is missing', () async {
      final source = TestSource({});
      final scalar = ConfString();
      final result = await scalar.load(source, keyA);
      expect(result.hasErrors, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.key, equals(keyA));
      expect(result.errors.first.source, equals(source));
      expect(result.errors.first.message, equals('Expected a value.'));
    });

    test('reports error when value is invalid', () async {
      final source = TestSource({'a': 'b'});
      final scalar = ConfBoolean();
      final result = await scalar.load(source, keyA);
      expect(result.hasErrors, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.key, equals(keyA));
      expect(result.errors.first.source, equals(source));
      expect(
        result.errors.first.message,
        equals('FormatException: Expected a boolean value but got "b".'),
      );
    });

    test('builtin scalar types', () async {
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
      final result = await BuiltinScalarsObject.schema.load(source);
      expect(result.hasErrors, isFalse);
      final value = result.value!;
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

  test('ConfNullable', () async {
    final source = TestSource({'a': 'true'});
    final scalar = ConfNullable(ConfBoolean());
    var result = await scalar.load(source, keyA);
    expect(result.hasErrors, isFalse);
    expect(result.value, isTrue);
    result = await scalar.load(source, ConfigurationKey(const ['b']));
    expect(result.hasErrors, isFalse);
    expect(result.value, isNull);
  });

  test('ConfDefault', () async {
    final source = TestSource({'a': 'true'});
    final scalar = ConfDefault(ConfBoolean(), defaultValue: false);
    var result = await scalar.load(source, keyA);
    expect(result.hasErrors, isFalse);
    expect(result.value, isTrue);
    result = await scalar.load(source, ConfigurationKey(const ['b']));
    expect(result.hasErrors, isFalse);
    expect(result.value, isFalse);
  });

  group('ConfList', () {
    test('reports errors from child values', () async {
      final source = TestSource({
        'a': ['a']
      });
      final list = ConfList(ConfBoolean());
      final result = await list.load(source, keyA);
      expect(result.hasErrors, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.source, equals(source));
      expect(result.errors.first.key, equals(keyA + 0));
      expect(
        result.errors.first.message,
        equals('FormatException: Expected a boolean value but got "a".'),
      );
    });

    test('empty list', () async {
      final source = TestSource({'a': []});
      final list = ConfList(ConfString());
      final result = await list.load(source, keyA);
      expect(result.hasErrors, isFalse);
      expect(result.value, isEmpty);
    });

    test('1 element list', () async {
      final source = TestSource({
        'a': ['a']
      });
      final list = ConfList(ConfString());
      final result = await list.load(source, keyA);
      expect(result.hasErrors, isFalse);
      expect(result.value, equals(['a']));
    });

    test('3 element list', () async {
      final source = TestSource({
        'a': ['a', 'b', 'c']
      });
      final list = ConfList(ConfString());
      final result = await list.load(source, keyA);
      expect(result.hasErrors, isFalse);
      expect(result.value, equals(['a', 'b', 'c']));
    });
  });

  group('ConfObject', () {
    test('reports errors from child values', () async {
      final source = TestSource({'a': 'a'});
      final object =
          ConfObject(properties: {'a': ConfBoolean()}, factory: (map) => map);
      final result = await object.load(source);
      expect(result.hasErrors, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.source, equals(source));
      expect(result.errors.first.key, equals(keyA));
      expect(
        result.errors.first.message,
        equals('FormatException: Expected a boolean value but got "a".'),
      );
    });

    test('throws when property names are not unique', () {
      expect(
        () => ConfObject.fromProperties(
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
      final object = ConfObject(properties: {}, factory: (map) => map);
      final result = await object.load(source);
      expect(result.hasErrors, isFalse);
      expect(result.value, equals({}));
    });

    test('1 property object', () async {
      final source = TestSource({'a': 'a'});
      final object =
          ConfObject(properties: {'a': ConfString()}, factory: (map) => map);
      final result = await object.load(source);
      expect(result.hasErrors, isFalse);
      expect(result.value, equals({'a': 'a'}));
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

  factory BuiltinScalarsObject.fromMap(Map<String, Object?> json) =>
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
    properties: {
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
    factory: BuiltinScalarsObject.fromMap,
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
