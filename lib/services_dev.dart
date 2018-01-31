// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A dev-time only server.
library services_dev;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;

import 'src/common.dart';
import 'src/common_server.dart';
import 'src/dartpad_support_server.dart';

Logger _logger = new Logger('services');

void main(List<String> args) {
  var parser = new ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '8080');
  parser.addFlag('discovery');
  parser.addFlag('relay');
  parser.addOption('server-url', defaultsTo: 'http://localhost');

  var result = parser.parse(args);
  var port = int.parse(result['port'], onError: (val) {
    stdout.writeln('Could not parse port value "$val" into a number.');
    exit(1);
  });

  String sdk = sdkPath;

  void printExit(String doc) {
    print(doc);
    exit(0);
  }

  if (result['discovery']) {
    var serverUrl = result['server-url'];
    if (result['relay']) {
      EndpointsServer
          .generateRelayDiscovery(sdk, serverUrl)
          .then((doc) => printExit(doc));
    } else {
      EndpointsServer
          .generateDiscovery(sdk, serverUrl)
          .then((doc) => printExit(doc));
    }
    return;
  }

  Logger.root.level = Level.ALL;
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
    EndpointsServer endpointsServer = new EndpointsServer._(sdkPath, port);

    return shelf
        .serve(endpointsServer.handler, InternetAddress.ANY_IP_V4, port)
        .then((HttpServer server) {
      endpointsServer.server = server;
      return endpointsServer;
    });
  }

  static Future<String> generateDiscovery(
      String sdkPath, String serverUrl) async {
    var commonServer = new CommonServer(sdkPath, new _ServerContainer(),
        new _Cache(), new _Counter());
    await commonServer.init();
    var apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true)
      ..addApi(commonServer);
    apiServer.enableDiscoveryApi();

    var uri = Uri.parse("/api/discovery/v1/apis/dartservices/v1/rest");
    var request =
        new HttpApiRequest('GET', uri, {}, new Stream.fromIterable([]));
    HttpApiResponse response = await apiServer.handleHttpApiRequest(request);
    return UTF8.decode(await response.body.first);
  }

  static Future<String> generateRelayDiscovery(
      String sdkPath, String serverUrl) async {
    var databaseServer = new FileRelayServer();
    var apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true)
      ..addApi(databaseServer);
    apiServer.enableDiscoveryApi();

    var uri =
        Uri.parse("/api/discovery/v1/apis/_dartpadsupportservices/v1/rest");
    var request =
        new HttpApiRequest('GET', uri, {}, new Stream.fromIterable([]));
    HttpApiResponse response = await apiServer.handleHttpApiRequest(request);
    return UTF8.decode(await response.body.first);
  }

  final int port;
  HttpServer server;

  Pipeline pipeline;
  Handler handler;

  ApiServer apiServer;
  bool discoveryEnabled;
  CommonServer commonServer;

  EndpointsServer._(String sdkPath, this.port) {
    discoveryEnabled = false;
    commonServer = new CommonServer(sdkPath, new _ServerContainer(),
        new _Cache(), new _Counter());
    commonServer.init();
    apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true)
      ..addApi(commonServer);

    pipeline = new Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_createCustomCorsHeadersMiddleware());

    handler = pipeline.addHandler(_apiHandler);
  }

  Future<Response> _apiHandler(Request request) {
    if (!discoveryEnabled) {
      apiServer.enableDiscoveryApi();
      discoveryEnabled = true;
    }

    // NOTE: We could read in the request body here and parse it similar to the
    // _parseRequest method to determine content-type and dispatch to e.g. a
    // plain text handler if we want to support that.
    HttpApiRequest apiRequest = new HttpApiRequest(
        request.method, request.requestedUri, request.headers, request.read());

    // Promote text/plain requests to application/json.
    if (apiRequest.headers['content-type'] == 'text/plain; charset=utf-8') {
      apiRequest.headers['content-type'] = 'application/json; charset=utf-8';
    }

    return apiServer
        .handleHttpApiRequest(apiRequest)
        .then((HttpApiResponse apiResponse) {
      return new Response(apiResponse.status,
          body: apiResponse.body, headers: apiResponse.headers);
    }).catchError((e) => printUsage(request));
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
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, X-Requested-With, Content-Type, Accept'
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

/**
 * This is a mock implementation of a counter, it doesn't use a proper
 * persistent store.
 */
class _Counter implements PersistentCounter {
  final Map<String, int> _map = {};

  @override
  Future<int> getTotal(String name) {
    _map.putIfAbsent(name, () => 0);

    return new Future.value(_map[name]);
  }

  @override
  Future increment(String name, {int increment: 1}) {
    _map.putIfAbsent(name, () => 0);
    _map[name]++;
    return new Future.value();
  }
}
