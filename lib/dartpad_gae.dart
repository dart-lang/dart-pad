// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_gae;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:appengine/appengine.dart';
import 'package:crypto/crypto.dart';
import 'package:memcache/memcache.dart';

import 'src/analyzer.dart';
import 'src/compiler.dart';

Logging get logging => context.services.logging;
Memcache get memcache => context.services.memcache;

var sdkPath = '/usr/lib/dart';
Analyzer analyzer = new Analyzer(sdkPath);
Compiler compiler = new Compiler(sdkPath);

main() {
  runAppEngine((io.HttpRequest request) {
    requestHandler(request);
  });
}

Future<String> checkCache(String query) {
  return memcache.get(query);
}

setCache(String query, String result) {
  return memcache.set(query, result);
}

void requestHandler(io.HttpRequest request) {
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers.add('Access-Control-Allow-Credentials', 'true');

  if (request.uri.path == '/api/analyze') {
    handleAnalyzePost(request);
  } else if (request.uri.path == '/api/compile') {
    handleCompilePost(request);
  } else if (request.uri.path == '/api/complete') {
    handleCompletePost(request);
  } else if (request.uri.path == '/api/document') {
    handleDocumentPost(request);
  } else {
    request.response.statusCode = io.HttpStatus.NOT_FOUND;
    request.response.close();
  }
}

handleAnalyzePost(io.HttpRequest request) {
  io.BytesBuilder builder = new io.BytesBuilder();
  Map<String, String> params = request.requestedUri.queryParameters;

  request.listen((buffer) {
    builder.add(buffer);
  }, onDone: () {

    String source = UTF8.decode(builder.toBytes());
    logging.info("ANALYZE: $source");
    Stopwatch watch = new Stopwatch()..start();

    try {
      analyzer.analyze(source).then((AnalysisResults results) {
        List issues = results.issues.map((issue) => issue.toMap()).toList();
        String json = JSON.encode(issues);

        int lineCount = source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        logging.info('PERF: Analyzed ${lineCount} lines of Dart in ${ms}ms.');
        request.response.writeln(json);
        request.response.close();
      }).catchError((e) {
        request.response.statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR;
        request.response.writeln(e);
        request.response.close();
      });
    } catch (e) {
      request.response.statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR;
      request.response.writeln(e);
      request.response.close();
    }
  });
}

handleCompletePost(io.HttpRequest request) {
  // TODO: implement
  request.response.statusCode = io.HttpStatus.NOT_IMPLEMENTED;
  request.response.writeln('Unimplemented: /api/complete');
  request.response.close();
}

handleDocumentPost(io.HttpRequest request) {
  io.BytesBuilder builder = new io.BytesBuilder();
  Map<String, String> params = request.requestedUri.queryParameters;

  request.listen((buffer) {
    builder.add(buffer);
  }, onDone: () {
    String requestJSON = UTF8.decode(builder.toBytes());
    logging.info("DOCUMENT: $requestJSON");

    Map m = JSON.decode(requestJSON);
    String source = m['source'];
    int offset = m['offset'];

    Stopwatch watch = new Stopwatch()..start();

    try {
      analyzer.dartdoc(source, offset).then((Map docInfo) {
        if (docInfo == null) docInfo = {};
        String json = JSON.encode(docInfo);
        logging.info('PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
        request.response.writeln(json);
        request.response.close();
      }).catchError((e) {
        request.response.statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR;
        request.response.writeln(e);
        request.response.close();
      });
    } catch (e) {
      request.response.statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR;
      request.response.writeln(e);
      request.response.close();
    }
  });
}

handleCompilePost(io.HttpRequest request) {
  io.BytesBuilder builder = new io.BytesBuilder();
  Map<String, String> params = request.requestedUri.queryParameters;

  request.listen((buffer) {
    builder.add(buffer);
  }, onDone: () {

    List<int> sourceBytes = builder.toBytes();
    String sourceHash = _hashSource(sourceBytes);
    String source = UTF8.decode(sourceBytes);

    logging.info("COMPILE: $source");
    checkCache("%%COMPILE:$sourceHash").then((String r) {
      if (r != null) {
        logging.info("CACHE: Cache hit for compile");
        request.response.writeln(r);
        request.response.close();
      } else {
        Stopwatch watch = new Stopwatch()..start();
        compiler.compile(source).then((CompilationResults results) {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            logging.info('PERF: Compiled ${lineCount} lines of Dart into '
                '${outputSize}kb of JavaScript in ${ms}ms.');
            String out = results.getOutput();
            setCache("%%COMPILE:$sourceHash", out).then((_) {
              request.response.writeln(out);
              request.response.close();
            });
          } else {
            String errors = results.problems.map(_printProblem).join('\n');
            request.response.statusCode = io.HttpStatus.BAD_REQUEST;
            request.response.writeln(errors);
            request.response.close();
          }
        }).catchError((e, st) {
          String errorText = 'Error during compile: ${e}\n${st}';
          request.response.statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR;
          request.response.writeln(errorText);
          request.response.close();
        });
      }
    });
  });
}

String _printProblem(CompilationProblem problem) =>
    '[${problem.kind}, line ${problem.line}] ${problem.message}';

String _hashSource(List<int> sourceBytes) {
  SHA1 sha1 = new SHA1();
  sha1.add(sourceBytes);
  return CryptoUtils.bytesToHex(sha1.close());
}
