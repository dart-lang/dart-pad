// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;

import 'src/common_server_api.dart';
import 'src/common_server_impl.dart';
import 'src/github_oauth_handler.dart';
import 'src/logging.dart';
import 'src/sdk.dart';
import 'src/server_cache.dart';

final Logger _logger = Logger('services');

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('channel',
        valueHelp: 'channel', help: 'The SDK channel (required).')
    ..addOption('port', valueHelp: 'port', help: 'The port to listen on.')
    ..addOption('redis-url', valueHelp: 'url', help: 'The redis server url.')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show this usage information.');

  final results = parser.parse(args);
  if (results['help'] as bool) {
    print('dart bin/server.dart <options>\n');
    print(parser.usage);
    exit(0);
  }

  if (!results.wasParsed('channel')) {
    print('error: --channel is required.\n');
    print(parser.usage);
    exit(1);
  }

  if (!results.wasParsed('redis-url')) {
    print('warning: no redis server specified.\n');
  }

  final channel = results['channel'] as String;
  final sdk = Sdk.create(channel);

  var port = 8080;

  // Read port from args; fall back to using an env. variable.
  if (results.wasParsed('port')) {
    port = int.parse(results['port'] as String);
  } else if (Platform.environment.containsKey('PORT')) {
    port = int.parse(Platform.environment['PORT']!);
  }

  Logger.root.level = Level.FINER;
  emitLogsToStdout();

  final redisServerUri = results['redis-url'] as String?;

  final cloudRunEnvVars = Platform.environment.entries
      .where((entry) => entry.key.startsWith('K_'))
      .map((entry) => '  ${entry.key}: ${entry.value}')
      .join('\n');

  _logger.info('''
Initializing dart-services:
port: $port
sdkPath: ${sdk.dartSdkPath}
redisServerUri: $redisServerUri
Cloud Run Environment variables:
$cloudRunEnvVars'''
      .trim());

  await GitHubOAuthHandler.initFromEnvironmentalVars();

  await EndpointsServer.serve(port, sdk, redisServerUri);

  _logger.info('Listening on port $port');
}

class EndpointsServer {
  static Future<EndpointsServer> serve(
    int port,
    Sdk sdk,
    String? redisServerUri,
  ) async {
    final endpointsServer = EndpointsServer._(redisServerUri, sdk);
    await endpointsServer.init();

    endpointsServer.server = await shelf.serve(
      endpointsServer.handler,
      InternetAddress.anyIPv4,
      port,
    );

    return endpointsServer;
  }

  late final HttpServer server;

  late final Pipeline pipeline;
  late final Handler handler;

  late final CommonServerApi commonServerApi;
  late final CommonServerImpl _commonServerImpl;

  EndpointsServer._(String? redisServerUri, Sdk sdk) {
    // The name of the Cloud Run revision being run, for more detail please see:
    // https://cloud.google.com/run/docs/reference/container-contract#env-vars
    final serverVersion = Platform.environment['K_REVISION'];

    _commonServerImpl = CommonServerImpl(
      redisServerUri == null
          ? NoopCache()
          : RedisCache(redisServerUri, sdk, serverVersion),
      sdk,
    );
    commonServerApi = CommonServerApi(_commonServerImpl);

    // Set cache for GitHub OAuth and add GitHub OAuth routes to our router.
    GitHubOAuthHandler.setCache(
      redisServerUri == null
          ? InMemoryCache()
          : RedisCache(redisServerUri, sdk, serverVersion),
    );
    GitHubOAuthHandler.addRoutes(commonServerApi.router);

    pipeline = const Pipeline()
        .addMiddleware(logRequestsToLogger(_logger))
        .addMiddleware(createCustomCorsHeadersMiddleware());

    handler = pipeline.addHandler(commonServerApi.router.call);
  }

  Future<void> init() => _commonServerImpl.init();
}
