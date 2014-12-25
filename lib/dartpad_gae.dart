// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_gae;

import 'dart:io' as io;
import 'dart:async';
import 'dart:convert';
import 'package:appengine/appengine.dart';
import 'src/analyzer.dart';
import 'src/compiler.dart';

var logging;
var memcache;
var sdkPath = '/usr/lib/dart';
var analyzer = new Analyzer(sdkPath);
var compiler = new Compiler(sdkPath);

main() {
  runAppEngine((io.HttpRequest request) {
    logging = context.services.logging;
    memcache = context.services.memcache;
    requestHandler(request);
  });
}

Future<String> checkCache(String query) {
  return memcache.get(query);
}

void setCache(String query, String result) {
  memcache.set(query, result);
}

void requestHandler(io.HttpRequest request) {
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers.add('Access-Control-Allow-Credentials', 'true');

  if (request.uri.path == '/api/analyze') {
    handleAnalyzePost(request);
  } else if (request.uri.path == '/api/compile') {
    handleCompilePost(request);
  } else {
    request.response.statusCode = 404;
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
    Stopwatch watch = new Stopwatch()..start();

    try {
      analyzer.analyze(source).then((AnalysisResults results) {
        List issues = results.issues.map((issue) => issue.toMap()).toList();
        String json = JSON.encode(issues);

        int lineCount = source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        logging.info('Analyzed ${lineCount} lines of Dart in ${ms}ms.');
        request.response.writeln(json);
        request.response.close();
        });
      }
    catch (e) {
      request.response.statusCode = 500;
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

    String source = UTF8.decode(builder.toBytes());
    checkCache("%%COMPILE:" +source).then((String r) {
      if (r != null) {
        logging.info("Cache hit for compile");
        request.response.writeln(r);
        request.response.close();
      } else {
        Stopwatch watch = new Stopwatch()..start();
        compiler.compile(source).then((CompilationResults results) {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            logging.info('Compiled ${lineCount} lines of Dart into '
                '${outputSize}kb of JavaScript in ${ms}ms.');
            String out = results.getOutput();
            request.response.writeln(out);
            setCache("%%COMPILE:" + source, out);
          }
          request.response.close();
        });
      }
    });
  });
}
