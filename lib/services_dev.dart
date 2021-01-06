// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A dev-time only server.
library services_dev;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;

import 'src/common_server_api.dart';
import 'src/common_server_impl.dart';
import 'src/flutter_web.dart';
import 'src/server_cache.dart';
import 'src/shelf_cors.dart' as shelf_cors;

final Logger _logger = Logger('services');

void main(List<String> args) {
  final parser = ArgParser();
  parser
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('server-url', defaultsTo: 'http://localhost')
    ..addOption('proxy-target',
        help: 'URL base to proxy compilation requests to');

  final result = parser.parse(args);
  final port = int.tryParse(result['port'] as String);
  if (port == null) {
    stdout.writeln(
        'Could not parse port value "${result['port']}" into a number.');
    exit(1);
  }

  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((LogRecord record) {
    print(record);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  EndpointsServer.serve(port, result['proxy-target'].toString())
      .then((EndpointsServer server) {
    _logger.info('Listening on port ${server.port}');
  });
}

class EndpointsServer {
  static Future<EndpointsServer> serve(int port, String proxyTarget) {
    final endpointsServer = EndpointsServer._(port, proxyTarget);

    return shelf
        .serve(endpointsServer.handler, InternetAddress.anyIPv4, port)
        .then((HttpServer server) {
      endpointsServer.server = server;
      return endpointsServer;
    });
  }

  final int port;
  HttpServer server;
  final String proxyTarget;

  Pipeline pipeline;
  Handler handler;

  CommonServerApi commonServerApi;
  FlutterWebManager flutterWebManager;

  EndpointsServer._(this.port, this.proxyTarget) {
    final commonServerImpl = (proxyTarget != null && proxyTarget.isNotEmpty)
        ? CommonServerImplProxy(proxyTarget)
        : CommonServerImpl(
            _ServerContainer(),
            _Cache(),
          );
    commonServerApi = CommonServerApi(commonServerImpl);
    commonServerImpl.init();

    pipeline = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_createCustomCorsHeadersMiddleware());

    handler = pipeline.addHandler(commonServerApi.router);
  }

  Middleware _createCustomCorsHeadersMiddleware() {
    return shelf_cors.createCorsHeadersMiddleware(corsHeaders: <String, String>{
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, X-Requested-With, Content-Type, Accept, x-goog-api-client'
    });
  }
}

class _ServerContainer implements ServerContainer {
  @override
  String get version => '1.0';
}

class _Cache implements ServerCache {
  @override
  Future<String> get(String key) => Future<String>.value(null);

  @override
  Future<void> set(String key, String value, {Duration expiration}) =>
      Future<void>.value();

  @override
  Future<void> remove(String key) => Future<void>.value();

  @override
  Future<void> shutdown() => Future<void>.value();
}
