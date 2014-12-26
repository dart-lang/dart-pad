// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'package:args/args.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_route/shelf_route.dart';

import 'src/analyzer.dart';
import 'src/compiler.dart';

const Map _textHtmlHeader = const {HttpHeaders.CONTENT_TYPE: 'text/html'};
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
    stdout.writeln("Could not locate the SDK; please start the server with the "
        "'--dart-sdk' option.");
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

  Analyzer analyzer;
  Compiler compiler;

  DartpadServer._(String sdkPath, this.port) {
    analyzer = new Analyzer(sdkPath);
    compiler = new Compiler(sdkPath);

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
    return request.readAsString().then((String source) {
      if (source.isEmpty) {
        return new Future.value(new Response(400, body: "No source received"));
      }

      Stopwatch watch = new Stopwatch()..start();

      return analyzer.analyze(source).then((AnalysisResults results) {
        List issues = results.issues.map((issue) => issue.toMap()).toList();
        String json = JSON.encode(issues);

        int lineCount = source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        _logger.info('Analyzed ${lineCount} lines of Dart in ${ms}ms.');

        return new Response.ok(json, headers: _jsonHeader);
      }).catchError((e, st) {
        String errorText = 'Error during analysis: ${e}\n${st}';
        return new Response(500, body: errorText);
      });
    });
  }

  Future<Response> handleCompilePost(Request request) {
    return request.readAsString().then((String source) {
        if (source.isEmpty) {
          return new Future.value(new Response(400, body: "No source received"));
        }

        Stopwatch watch = new Stopwatch()..start();

        return compiler.compile(source).then((CompilationResults results) {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            _logger.info('Compiled ${lineCount} lines of Dart into '
                '${outputSize}kb of JavaScript in ${ms}ms.');

            return new Response.ok(results.getOutput(), headers: _textPlainHeader);
          } else {
            String errors = results.problems.map(_printProblem).join('\n');
            return new Response(400, body: errors);
          }
        }).catchError((e, st) {
          String errorText = 'Error during compile: ${e}\n${st}';
          return new Response(500, body: errorText);
        });
    });
  }

  Future<Response> handleCompletePost(Request request) {
    return request.readAsString().then((String json) {
      if (json.isEmpty) {
        return new Future.value(new Response(400, body: "No source received"));
      }

      // TODO: Add error handling.
      Map m = JSON.decode(json);
      String source = m['source'];
      int offset = m['offset'];

      // TODO: implement
      String errorText = 'Unimplemented: /api/complete';
      return new Response(500, body: errorText);
    });
  }

  Future<Response> handleDocumentPost(Request request) {
    return request.readAsString().then((String json) {
      if (json.isEmpty) {
        return new Future.value(new Response(400, body: "No source received"));
      }

      // TODO: Add error handling.
      Map m = JSON.decode(json);
      String source = m['source'];
      int offset = m['offset'];

      Stopwatch watch = new Stopwatch()..start();

      return analyzer.dartdoc(source, offset).then((Map dartdoc) {
        if (dartdoc == null) dartdoc = {};
        _logger.info('Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
        return new Response.ok(JSON.encode(dartdoc), headers: _textPlainHeader);
      }).catchError((e, st) {
        String errorText = 'Error during analysis: ${e}\n${st}';
        return new Response(500, body: errorText);
      });
    });
  }

  String _printProblem(CompilationProblem problem) {
    return '[${problem.kind}, line ${problem.line}] ${problem.message}';
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
