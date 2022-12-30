import 'package:conf/conf.dart';
import 'package:test/test.dart';

final keyA = ConfigurationKey(const ['a']);

class TestSource extends DataSource {
  TestSource(Map<String, Object?> data, [String? name])
      : super(description: name ?? 'test source', data: data);
}

Matcher configurationError(
  Object message, {
  Object? source,
  Object? key,
}) =>
    isA<ConfigurationError>()
        .having((error) => error.message, 'message', message)
        .having((error) => error.source, 'source', source)
        .having((error) => error.key, 'key', key);

Matcher configurationException(Object errors) => isA<ConfigurationException>()
    .having((exception) => exception.errors, 'errors', errors);
