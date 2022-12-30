// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:conf/conf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

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
    '${_prettyPrintJson(configuration.toJson())}',
  );

  if (!configuration.startServer) {
    return;
  }

  final router = _buildRouter();
  final middleware = _buildMiddleware(configuration);
  final handler = middleware.addHandler(router);
  final server = await shelf_io.serve(
    handler,
    configuration.address,
    configuration.port,
  );
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

Pipeline _buildMiddleware(ServerConfiguration configuration) {
  var middleware = const Pipeline();
  if (configuration.logRequests) {
    middleware = middleware.addMiddleware(logRequests());
  }
  return middleware;
}

Router _buildRouter() => Router()..get('/hello', _helloHandler);

Response _helloHandler(Request request) => Response.ok('Hello, world!');

String _prettyPrintJson(Object? json) =>
    const JsonEncoder.withIndent('  ').convert(json);
