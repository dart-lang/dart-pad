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
import 'src/github_oauth_handler.dart';
import 'src/sdk.dart';
import 'src/server_cache.dart';
import 'src/shelf_cors.dart' as shelf_cors;

final Logger _logger = Logger('services');

Future<void> main(List<String> args) async {
  final parser = ArgParser();
  parser
    ..addOption('channel', mandatory: true)
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('server-url', defaultsTo: 'http://localhost')
    ..addFlag('null-safety');

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

  await GitHubOAuthHandler.initFromEnvironmentalVars();

  await EndpointsServer.serve(port, Sdk.create(result['channel'] as String),
      result['null-safety'] as bool);
  _logger.info('Listening on port $port');
}

class EndpointsServer {
  static Future<EndpointsServer> serve(
      int port, Sdk sdk, bool nullSafety) async {
    final endpointsServer = EndpointsServer._(sdk, nullSafety);
    await shelf.serve(endpointsServer.handler, InternetAddress.anyIPv4, port);
    return endpointsServer;
  }

  late final Pipeline pipeline;
  late final Handler handler;
  late final CommonServerApi commonServerApi;

  EndpointsServer._(Sdk sdk, bool nullSafety) {
    final commonServerImpl = CommonServerImpl(
      _ServerContainer(),
      _Cache(),
      sdk,
    );
    commonServerApi = CommonServerApi(commonServerImpl);
    commonServerImpl.init();

    // Set cache for GitHub OAuth and add GitHub OAuth routes to our router.
    GitHubOAuthHandler.setCache(InMemoryCache());
    GitHubOAuthHandler.addRoutes(commonServerApi.router);

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
  Future<String?> get(String key) => Future<String?>.value(null);

  @override
  Future<void> set(String key, String value, {Duration? expiration}) =>
      Future<void>.value();

  @override
  Future<void> remove(String key) => Future<void>.value();

  @override
  Future<void> shutdown() => Future<void>.value();
}
