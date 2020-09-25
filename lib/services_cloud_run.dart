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

import 'src/common_server_api.dart';
import 'src/common_server_impl.dart';
import 'src/flutter_web.dart';
import 'src/sdk_manager.dart';
import 'src/server_cache.dart';
import 'src/shelf_cors.dart' as shelf_cors;

final Logger _logger = Logger('services');

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p')
    ..addOption('redis-url');
  final results = parser.parse(args);

  // Cloud Run supplies the port to bind to in the environment.
  // Allow command line arg to override environment.
  final port = int.tryParse(results['port'] as String ?? '') ??
      int.tryParse(Platform.environment['PORT'] ?? '');
  if (port == null) {
    stdout.writeln('Could not parse port value from either environment '
        '"PORT" or from command line argument "--port".');
    exit(1);
  }

  final redisServerUri = results['redis-url'] as String;

  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((LogRecord record) {
    print(record);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  final cloudRunEnvVars = Platform.environment.entries
      .where((entry) => entry.key.startsWith('K_'))
      .map((entry) => '${entry.key}: ${entry.value}')
      .join('\n');

  _logger.info('''Initializing dart-services:
    port: $port
    sdkPath: ${SdkManager.sdk.sdkPath}
    redisServerUri: $redisServerUri
    Cloud Run Environment variables:
    $cloudRunEnvVars''');

  final server = await EndpointsServer.serve(port, redisServerUri);
  _logger.info('Listening on port ${server.port}');
}

class EndpointsServer {
  static Future<EndpointsServer> serve(int port, String redisServerUri) {
    final endpointsServer = EndpointsServer._(port, redisServerUri);

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

  EndpointsServer._(this.port, this.redisServerUri) {
    final commonServerImpl = CommonServerImpl(
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
