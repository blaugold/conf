// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'configuration.dart';
import 'error.dart';

Future<void> startServer(List<String> arguments) async {
  try {
    await _startServer(arguments);
  } on FatalException catch (error) {
    exitCode = error.exitCode;
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
