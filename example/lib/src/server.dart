// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:conf/conf.dart';

import 'configuration.dart';

Future<void> startServer(List<String> arguments) async {
  try {
    await _startServer(arguments);
  } on ConfigurationException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<void> _startServer(List<String> arguments) async {
  final configuration = await ServerConfiguration.load(arguments);
  print('Active profiles: ${Profile.active}');
  print(
    'Configuration:\n'
    '${const JsonEncoder.withIndent('  ').convert(configuration.toJson())}',
  );
}
