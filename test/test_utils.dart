import 'package:conf/conf.dart';

final keyA = ConfigurationKey(const ['a']);

class TestSource extends DataSource {
  TestSource(Map<String, Object?> data, [String? name])
      : super(description: name ?? 'test source', data: data);
}
