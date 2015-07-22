// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;
import 'package:shelf_route/shelf_route.dart';

import 'src/common_server.dart';
import 'src/dartpad_support_server.dart';

const Map _textPlainHeader = const {HttpHeaders.CONTENT_TYPE: 'text/plain'};
const Map _jsonHeader = const {HttpHeaders.CONTENT_TYPE: 'application/json'};

Logger _logger = new Logger('services');

void main(List<String> args) {
  var parser = new ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '8080');
  parser.addOption('dart-sdk');
  parser.addFlag('discovery');
  parser.addFlag('relay');
  parser.addOption('server-url', defaultsTo: 'http://localhost');

  var result = parser.parse(args);
  var port = int.parse(result['port'], onError: (val) {
    stdout.writeln('Could not parse port value "$val" into a number.');
    exit(1);
  });

  Directory sdkDir = cli_util.getSdkDir(args);
  if (sdkDir == null) {
    stdout.writeln(
        "Could not locate the SDK; "
        "please start the server with the '--dart-sdk' option.");
    exit(1);
  }
  
  printExit(String doc) {
    print(doc);
    exit(0);
  }
  
  if (result['discovery']) {
    var serverUrl = result['server-url'];
    if (result['relay']) {
      EndpointsServer.generateRelayDiscovery(sdkDir.path, serverUrl).then((doc)
          => printExit(doc));
    } else {
      EndpointsServer.generateDiscovery(sdkDir.path, serverUrl).then((doc) 
          => printExit(doc));
    }
    return;
  }
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print(r));

  EndpointsServer.serve(sdkDir.path, port).then((EndpointsServer server) {
    _logger.info('Listening on port ${server.port}');
  });
}

class EndpointsServer {
  static Future<EndpointsServer> serve(String sdkPath, int port) {
    EndpointsServer endpointsServer = new EndpointsServer._(sdkPath, port);

    return shelf.serve(
        endpointsServer.handler, InternetAddress.ANY_IP_V4, port).then((server) {
      endpointsServer.server = server;
      return endpointsServer;
    });
  }

  static Future<String> generateDiscovery(String sdkPath,
                                          String serverUrl) async {
    var commonServer = new CommonServer(
        sdkPath,
        new _ServerContainer(),
        new _Cache(),
        new _Recorder(),
        new _Counter());
    var apiServer =
        new ApiServer(apiPrefix: '/api', prettyPrint: true)..addApi(commonServer);
    apiServer.enableDiscoveryApi();

    var uri = Uri.parse("/api/discovery/v1/apis/dartservices/v1/rest");

    var request =
        new HttpApiRequest('GET',
                           uri,
                           {}, new Stream.fromIterable([]));
    HttpApiResponse response = await apiServer.handleHttpApiRequest(request);
    return UTF8.decode(await response.body.first);
  }
  
  static Future<String> generateRelayDiscovery(String sdkPath,
                                            String serverUrl) async {
    var databaseServer = new FileRelayServer();
    var apiServer =
        new ApiServer(apiPrefix: '/api', prettyPrint: true)..addApi(databaseServer);
    apiServer.enableDiscoveryApi();

    var uri = Uri.parse("/api/discovery/v1/apis/dartpadsupportservices/v1/rest");

    var request =
        new HttpApiRequest('GET',
                           uri,
                           {}, new Stream.fromIterable([]));
    HttpApiResponse response = await apiServer.handleHttpApiRequest(request);
    return UTF8.decode(await response.body.first);
  }

  final int port;
  HttpServer server;

  Pipeline pipeline;
  Router routes;
  Handler handler;

  ApiServer apiServer;
  bool discoveryEnabled;
  CommonServer commonServer;

  EndpointsServer._(String sdkPath, this.port) {
    discoveryEnabled = false;
    commonServer = new CommonServer(
        sdkPath,
        new _ServerContainer(),
        new _Cache(),
        new _Recorder(),
        new _Counter());
    apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true)..addApi(commonServer);

    pipeline = new Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_createCustomCorsHeadersMiddleware());

    routes = router()
        ..get('/', printUsage)
        ..add('/api', ['DELETE', 'GET', 'POST', 'OPTIONS'], _apiHandler,
              exactMatch: false);
    handler = pipeline.addHandler(routes.handler);
  }

  Future<Response> _apiHandler(Request request) {
    if (!discoveryEnabled) {
      apiServer.enableDiscoveryApi();
      discoveryEnabled = true;
    }
    // NOTE: We could read in the request body here and parse it similar to
    // the _parseRequest method to determine content-type and dispatch to e.g.
    // a plain text handler if we want to support that.
    var apiRequest = new HttpApiRequest(request.method, request.url,
                                        request.headers,
                                        request.read());
    return apiServer.handleHttpApiRequest(apiRequest)
        .then((HttpApiResponse apiResponse) {
          return new Response(apiResponse.status, body: apiResponse.body,
                              headers: apiResponse.headers);})
        .catchError((e) => printUsage(request));
  }

  Response printUsage(Request request) {
    return new Response.ok('''
Dart Services server

View the available API calls at /api/discovery/v1/apis/dartservices/v1/rest.
''');
  }

  Middleware _createCustomCorsHeadersMiddleware() {
    return shelf_cors.createCorsHeadersMiddleware(corsHeaders: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'DELETE, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept'
    });
  }
}

class _ServerContainer implements ServerContainer {
  String get version => '1.0';
}

class _Cache implements ServerCache {
  Future<String> get(String key) => new Future.value(null);
  Future set(String key, String value, {Duration expiration}) =>
      new Future.value();
  Future remove(String key) => new Future.value();
}

class _Recorder implements SourceRequestRecorder {
  Future record(String verb, String source, [int offset = -99]) {
    _logger.fine("$verb, $offset, $source");
    return new Future.value();
  }
}

/**
 * This is a mock implementation of a counter, it doesn't use
 * a proper persistent store.
 */
class _Counter implements PersistentCounter {
  final Map<String, int> _map = {};

  @override
  Future<int> getTotal(String name) {
    _map.putIfAbsent(name, () => 0);

    return new Future.value(_map[name]);
  }

  @override
  Future increment(String name, {int increment : 1}) {
    _map.putIfAbsent(name, () => 0);
    _map[name]++;
    return new Future.value();
  }
}
