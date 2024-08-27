// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_gzip/shelf_gzip.dart';

import 'src/caching.dart';
import 'src/common_server.dart';
import 'src/logging.dart';
import 'src/oauth_handler.dart';
import 'src/sdk.dart';

final Logger _logger = Logger('services');

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', valueHelp: 'port', help: 'The port to listen on.')
    ..addOption('redis-url', valueHelp: 'url', help: 'The redis server url.')
    ..addFlag('devtime',
        negatable: false,
        aliases: ['local'],
        help:
            'Indicate that the server is being run during development (not prod).')
    ..addOption('storage-bucket',
        valueHelp: 'name',
        help: 'The name of the Cloud Storage bucket for compilation artifacts.',
        defaultsTo: 'nnbd_artifacts')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show this usage information.');

  final results = parser.parse(args);
  if (results.flag('help')) {
    print('dart bin/server.dart <options>\n');
    print(parser.usage);
    exit(0);
  }

  if (!results.wasParsed('redis-url')) {
    print('warning: no redis server specified.\n');
  }

  final sdk = Sdk.fromLocalFlutter();

  final int port;

  // Read port from args; fall back to using an env. variable.
  if (results.wasParsed('port')) {
    port = int.parse(results.option('port')!);
  } else if (Platform.environment['PORT'] case final environmentPath?) {
    port = int.parse(environmentPath);
  } else {
    port = 8080;
  }

  Logger.root.level = Level.FINER;
  emitLogsToStdout();

  final redisServerUri = results.option('redis-url');
  final storageBucket = results.option('storage-bucket') ?? 'nnbd_artifacts';

  final devtime = results.flag('devtime');

  final cloudRunEnvVars = Platform.environment.entries
      .where((entry) => entry.key.startsWith('K_'))
      .map((entry) => '${entry.key}:${entry.value}')
      .join(',');

  _logger.info('''
Starting dart-services:
  port: $port
  sdkPath: ${sdk.dartSdkPath}
  redisServerUri: $redisServerUri
  Cloud Run Environment variables: $cloudRunEnvVars'''
      .trim());

  await GitHubOAuthHandler.initFromEnvironmentalVars();

  final server = await EndpointsServer.serve(
      port, sdk, redisServerUri, storageBucket,
      devtime: devtime);

  _logger.info('Listening on port ${server.port}');
}

class EndpointsServer {
  static Future<EndpointsServer> serve(
    int port,
    Sdk sdk,
    String? redisServerUri,
    String storageBucket, {
    bool devtime = false,
  }) async {
    final endpointsServer =
        EndpointsServer._(sdk, redisServerUri, storageBucket, devtime: devtime);
    await endpointsServer._init();

    endpointsServer.server = await shelf.serve(
      endpointsServer.handler,
      InternetAddress.anyIPv4,
      port,
    );

    return endpointsServer;
  }

  late final HttpServer server;
  late final Handler handler;
  late final CommonServerApi commonServer;

  EndpointsServer._(Sdk sdk, String? redisServerUri, String storageBucket,
      {bool devtime = false}) {
    // The name of the Cloud Run revision being run, for more detail please see:
    // https://cloud.google.com/run/docs/reference/container-contract#env-vars
    final serverVersion = Platform.environment['K_REVISION'];

    final cache = redisServerUri == null
        ? NoopCache()
        : RedisCache(redisServerUri, sdk, serverVersion);

    commonServer = CommonServerApi(
      CommonServerImpl(
        sdk,
        cache,
        storageBucket: storageBucket,
      ),
      devtime: devtime,
    );

    // Set cache for GitHub OAuth and add GitHub OAuth routes to our router.
    GitHubOAuthHandler.setCache(cache);
    GitHubOAuthHandler.addRoutes(commonServer.router);

    final pipeline = const Pipeline()
        .addMiddleware(logRequestsToLogger(_logger))
        .addMiddleware(createCustomCorsHeadersMiddleware())
        .addMiddleware(exceptionResponse())
        .addMiddleware(gzipMiddleware);

    handler = pipeline.addHandler(commonServer.router.call);
  }

  Future<void> _init() => commonServer.init();

  int get port => server.port;

  Future<void> close() async {
    await commonServer.shutdown();
    await server.close();
  }
}

Middleware exceptionResponse() {
  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (e, st) {
        if (e is BadRequest) {
          return Response.badRequest(body: e.message);
        }

        _logger.severe('${request.requestedUri.path} $e', null, st);

        return Response.badRequest(body: '$e');
      }
    };
  };
}
