// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A dev-time only server.
library services_dev;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;

import 'src/common.dart';
import 'src/common_server.dart';
import 'src/common_server_impl.dart';
import 'src/common_server_proto.dart';
import 'src/flutter_web.dart';
import 'src/server_cache.dart';
import 'src/shelf_cors.dart' as shelf_cors;

final Logger _logger = Logger('services');

void main(List<String> args) {
  final parser = ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '8080');
  parser.addFlag('discovery');
  parser.addFlag('relay');
  parser.addOption('server-url', defaultsTo: 'http://localhost');

  final result = parser.parse(args);
  final port = int.tryParse(result['port'] as String);
  if (port == null) {
    stdout.writeln(
        'Could not parse port value "${result['port']}" into a number.');
    exit(1);
  }

  final sdk = sdkPath;

  void printExit(String doc) {
    print(doc);
    exit(0);
  }

  if (result['discovery'] as bool) {
    final serverUrl = result['server-url'] as String;
    EndpointsServer.generateDiscovery(SdkManager.flutterSdk, serverUrl)
        .then(printExit);

    return;
  }

  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((LogRecord record) {
    print(record);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  EndpointsServer.serve(sdk, port).then((EndpointsServer server) {
    _logger.info('Listening on port ${server.port}');
  });
}

class EndpointsServer {
  static Future<EndpointsServer> serve(String sdkPath, int port) {
    final endpointsServer = EndpointsServer._(sdkPath, port);

    return shelf
        .serve(endpointsServer.handler, InternetAddress.anyIPv4, port)
        .then((HttpServer server) {
      endpointsServer.server = server;
      return endpointsServer;
    });
  }

  static Future<String> generateDiscovery(
      FlutterSdk flutterSdk, String serverUrl) async {
    final flutterWebManager = FlutterWebManager(flutterSdk);
    final commonServerImpl = CommonServerImpl(
      sdkPath,
      flutterWebManager,
      _ServerContainer(),
      _Cache(),
    );
    final commonServer = CommonServer(commonServerImpl);
    await commonServerImpl.init();
    final apiServer = ApiServer(apiPrefix: '/api', prettyPrint: true)
      ..addApi(commonServer);
    apiServer.enableDiscoveryApi();

    final uri = Uri.parse('/api/discovery/v1/apis/dartservices/v1/rest');
    final request = HttpApiRequest('GET', uri, <String, dynamic>{},
        Stream<List<int>>.fromIterable(<List<int>>[]));
    final response = await apiServer.handleHttpApiRequest(request);
    return utf8.decode(await response.body.first);
  }

  final int port;
  HttpServer server;

  Pipeline pipeline;
  Handler handler;

  ApiServer apiServer;
  bool discoveryEnabled;
  CommonServer commonServer;
  CommonServerProto commonServerProto;
  FlutterWebManager flutterWebManager;

  EndpointsServer._(String sdkPath, this.port) {
    discoveryEnabled = false;

    flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
    final commonServerImpl = CommonServerImpl(
      sdkPath,
      flutterWebManager,
      _ServerContainer(),
      _Cache(),
    );
    commonServer = CommonServer(commonServerImpl);
    commonServerProto = CommonServerProto(commonServerImpl);
    commonServerImpl.init();

    apiServer = ApiServer(apiPrefix: '/api', prettyPrint: true)
      ..addApi(commonServer);

    pipeline = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_createCustomCorsHeadersMiddleware());

    handler = pipeline.addHandler((request) {
      if (request.requestedUri.path.startsWith(PROTO_API_URL_PREFIX)) {
        return commonServerProto.router.handler(request);
      }
      return _apiHandler(request);
    });
  }

  Future<Response> _apiHandler(Request request) {
    if (!discoveryEnabled) {
      apiServer.enableDiscoveryApi();
      discoveryEnabled = true;
    }

    // NOTE: We could read in the request body here and parse it similar to the
    // _parseRequest method to determine content-type and dispatch to e.g. a
    // plain text handler if we want to support that.
    final apiRequest = HttpApiRequest(
        request.method, request.requestedUri, request.headers, request.read());

    // Promote text/plain requests to application/json.
    if (apiRequest.headers['content-type'] == 'text/plain; charset=utf-8') {
      apiRequest.headers['content-type'] = 'application/json; charset=utf-8';
    }

    return apiServer
        .handleHttpApiRequest(apiRequest)
        .then((HttpApiResponse apiResponse) {
      // TODO(jcollins-g): use sendApiResponse helper?
      return Response(apiResponse.status,
          body: apiResponse.body,
          headers: Map<String, String>.from(apiResponse.headers));
    });
  }

  Response printUsage(Request request, dynamic e, StackTrace stackTrace) {
    return Response.ok('''
Dart Services server

View the available API calls at /api/discovery/v1/apis/dartservices/v1/rest.

Error: $e
Stack Trace: ${stackTrace.toString()}
''');
  }

  Middleware _createCustomCorsHeadersMiddleware() {
    return shelf_cors.createCorsHeadersMiddleware(corsHeaders: <String, String>{
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
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
