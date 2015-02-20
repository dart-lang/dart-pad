// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_route/shelf_route.dart';
import 'package:rpc/rpc.dart';
import 'src/common_server.dart';

const Map _textPlainHeader = const {HttpHeaders.CONTENT_TYPE: 'text/plain'};
const Map _jsonHeader = const {HttpHeaders.CONTENT_TYPE: 'application/json'};

Logger _logger = new Logger('endpoints');

void main(List<String> args) {
  var parser = new ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '8080');
  parser.addOption('dart-sdk');

  var result = parser.parse(args);
  var port = int.parse(result['port'], onError: (val) {
    stdout.writeln('Could not parse port value "$val" into a number.');
    exit(1);
  });

  Directory sdkDir = grinder.getSdkDir(args);
  if (sdkDir == null) {
    stdout.writeln(
        "Could not locate the SDK; "
        "please start the server with the '--dart-sdk' option.");
    exit(1);
  }

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
    commonServer = new CommonServer(sdkPath, new _Logger(), new _Cache());
    apiServer = new ApiServer(prettyPrint: true)..addApi(commonServer);

    pipeline = new Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_createCorsMiddleware());

    routes = router()
        ..get('/', printUsage)
        ..add('/api', ['GET', 'POST', 'OPTIONS'], _apiHandler,
              exactMatch: false);
    handler = pipeline.addHandler(routes.handler);
  }

  Future<Response> _apiHandler(Request request) {
    if (!discoveryEnabled) {
      apiServer.enableDiscoveryApi(request.requestedUri.origin, '/api');
      discoveryEnabled = true;
    }
    // NOTE: We could read in the request body here and parse it similar to
    // the _parseRequest method to determine content-type and dispatch to e.g.
    // a plain text handler if we want to support that.
    var apiRequest = new HttpApiRequest(request.method, request.url.path,
                                        request.url.queryParameters,
                                        request.headers['content-type'],
                                        request.read());
    return apiServer.handleHttpRequest(apiRequest)
        .then((HttpApiResponse apiResponse) {
          return new Response(apiResponse.status, body: apiResponse.body,
                              headers: apiResponse.headers);})
        .catchError((e) => printUsage(request));
  }

  Response printUsage(Request request) {
    return new Response.ok('''
Dart Endpoints server.

POST /api/dartServices/v1/analyze  - Send Dart source as JSON to this URL and get JSON errors and warnings back.
GET  /api/dartServices/v1/analyze  - Send Dart source to this URL as url query string and get JSON errors and warnings back.
POST /api/dartServices/v1/compile  - Send Dart source as JSON to this URL and get compiled results back.
GET  /api/dartServices/v1/compile  - Send Dart source to this URL as url query string and compiled results back.
POST /api/dartServices/v1/complete - TODO:
GET  /api/dartServices/v1/complete - TODO:
POST /api/dartServices/v1/document - Send Dart source as JSON (source, offset) to the URL to calculate dartdoc.
GET  /api/dartServices/v1/document - Send Dart source to this URL as url query string (source, offset) to calculate dartdoc.
''');
  }

  Middleware _createCorsMiddleware() {
    Map _corsHeader = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept'
    };

    Response _options(Request request) => (request.method == 'OPTIONS') ?
        new Response.ok(null, headers: _corsHeader) : null;
    Response _cors(Response response) => response.change(headers: _corsHeader);

    return createMiddleware(requestHandler: _options, responseHandler: _cors);
  }
}

class _Logger implements ServerLogger {
  void info(String message) => _logger.info(message);
  void warn(String message) => _logger.warning(message);
  void error(String message) => _logger.severe(message);
}

class _Cache implements ServerCache {
  Future<String> get(String key) => new Future.value(null);
  Future set(String key, String value, {Duration expiration}) =>
      new Future.value();
  Future remove(String key) => new Future.value();
}
