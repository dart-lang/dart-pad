// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_route/shelf_route.dart';

import 'src/common_server.dart';

const Map _textPlainHeader = const {HttpHeaders.CONTENT_TYPE: 'text/plain'};
const Map _jsonHeader = const {HttpHeaders.CONTENT_TYPE: 'application/json'};

Logger _logger = new Logger('dartpad');

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

  DartpadServer.serve(sdkDir.path, port).then((DartpadServer server) {
    print('Listening on port ${server.port}');
  });
}

class DartpadServer {
  static Future<DartpadServer> serve(String sdkPath, int port) {
    DartpadServer dartpad = new DartpadServer._(sdkPath, port);

    return shelf.serve(
        dartpad.handler, InternetAddress.ANY_IP_V4, port).then((server) {
      dartpad.server = server;
      return dartpad;
    });
  }

  final int port;
  HttpServer server;

  Pipeline pipeline;
  Router routes;
  Handler handler;

  CommonServer commonServer;

  DartpadServer._(String sdkPath, this.port) {
    commonServer = new CommonServer(sdkPath, new _Logger(), new _Cache());

    pipeline = new Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_createCorsMiddleware());

    routes = router();
    routes.get('/', handleRoot);
    routes.get('/api', handleApiRoot);
    routes.post('/api/analyze', handleAnalyzePost);
    routes.post('/api/compile', handleCompilePost);
    routes.post('/api/complete', handleCompletePost);
    routes.post('/api/document', handleDocumentPost);

    handler = pipeline.addHandler(routes.handler);
  }

  Response handleRoot(Request request) {
    return new Response.ok('Dartpad server. See /api for more information.');
  }

  Response handleApiRoot(Request request) {
    return new Response.ok('''
Dartpad server.

/api/analyze  - POST Dart source to this URL and get JSON errors and warnings back.
/api/compile  - POST Dart source to this URL and get compiled results back.
/api/complete - TODO:
/api/document - POST json encoded (source, offset) to the URL to calculate dartdoc.:
''');
  }

  Future<Response> handleAnalyzePost(Request request) {
    return request.readAsString().then((String data) {
      String contentType = request.headers[HttpHeaders.CONTENT_TYPE];
      return commonServer.handleAnalyze(data, contentType).then(_convertResponse);
    });
  }

  Future<Response> handleCompilePost(Request request) {
    return request.readAsString().then((String data) {
      String contentType = request.headers[HttpHeaders.CONTENT_TYPE];
      return commonServer.handleCompile(data, contentType).then(_convertResponse);
    });
  }

  Future<Response> handleCompletePost(Request request) {
    return request.readAsString().then((String data) {
      String contentType = request.headers[HttpHeaders.CONTENT_TYPE];
      return commonServer.handleComplete(data, contentType).then(_convertResponse);
    });
  }

  Future<Response> handleDocumentPost(Request request) {
    return request.readAsString().then((String data) {
      String contentType = request.headers[HttpHeaders.CONTENT_TYPE];
      return commonServer.handleDocument(data, contentType).then(_convertResponse);
    });
  }

  Response _convertResponse(ServerResponse response) {
    String mime = response.mimeType != null ? response.mimeType : 'text/plain';

    return new Response(
        response.statusCode,
        headers: { HttpHeaders.CONTENT_TYPE: mime + '; charset=utf-8' },
        body: response.data);
  }

  Middleware _createCorsMiddleware() {
    Map _corsHeader = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
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
