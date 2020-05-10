// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A server for Cloud Run.
library services_cloud_run;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;

import 'src/common.dart';
import 'src/common_server_api.dart';
import 'src/common_server_impl.dart';
import 'src/flutter_web.dart';
import 'src/sdk_manager.dart';
import 'src/server_cache.dart';
import 'src/shelf_cors.dart' as shelf_cors;

final Logger _logger = Logger('services');

void main(List<String> args) {
  final parser = ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '8080');
  parser.addOption('server-url', defaultsTo: 'http://localhost');
  parser.addOption('redis-url');

  final result = parser.parse(args);
  final port = int.tryParse(result['port'] as String);
  if (port == null) {
    stdout.writeln(
        'Could not parse port value "${result['port']}" into a number.');
    exit(1);
  }
  final redisServerUri = result['redis-url'] as String;
  final sdk = sdkPath;

  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((LogRecord record) {
    print(record);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  EndpointsServer.serve(sdk, port, redisServerUri)
      .then((EndpointsServer server) {
    _logger.info('Listening on port ${server.port}');
  });
}

class EndpointsServer {
  static Future<EndpointsServer> serve(
      String sdkPath, int port, String redisServerUri) {
    final endpointsServer = EndpointsServer._(sdkPath, port, redisServerUri);

    return shelf
        .serve(endpointsServer.handler, InternetAddress.anyIPv4, port)
        .then((HttpServer server) {
      endpointsServer.server = server;
      return endpointsServer;
    });
  }

  final int port;
  HttpServer server;
  String redisServerUri;

  Pipeline pipeline;
  Handler handler;

  CommonServerApi commonServerApi;
  FlutterWebManager flutterWebManager;

  EndpointsServer._(String sdkPath, this.port, this.redisServerUri) {
    flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
    final commonServerImpl = CommonServerImpl(
      sdkPath,
      flutterWebManager,
      _ServerContainer(),
      redisServerUri == null
          ? InMemoryCache()
          : RedisCache(
              redisServerUri,
              // The name of the Cloud Run revision being run, for more detail please see:
              // https://cloud.google.com/run/docs/reference/container-contract#env-vars
              Platform.environment['K_REVISION'],
            ),
    );
    commonServerApi = CommonServerApi(commonServerImpl);
    commonServerImpl.init();

    pipeline = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_createCustomCorsHeadersMiddleware());

    handler = pipeline.addHandler(commonServerApi.router.handler);
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
