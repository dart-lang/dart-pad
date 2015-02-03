// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library endpoints.common_server;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'analyzer.dart';
import 'compiler.dart';

final Duration _standardExpiration = new Duration(hours: 1);

const String _json = 'application/json';
const String _plain = 'text/plain';
const String _urlEncoded = 'application/x-www-form-urlencoded';

abstract class ServerLogger {
  void info(String message);
  void warn(String message);
  void error(String message);
}

abstract class ServerCache {
  Future<String> get(String key);
  Future set(String key, String value, {Duration expiration});
  Future remove(String key);
}

class ServerResponse {
  final int statusCode;
  final String data;

  String _mimeType;

  String get mimeType => _mimeType;

  ServerResponse(this.statusCode, this.data, [this._mimeType]);

  ServerResponse.asJson(this.data):
    statusCode = HttpStatus.OK, _mimeType = _json;

  ServerResponse.badRequest(this.data):
    statusCode = HttpStatus.BAD_REQUEST;

  ServerResponse.notImplemented(this.data):
    statusCode = HttpStatus.NOT_IMPLEMENTED;

  ServerResponse.internalError(this.data):
    statusCode = HttpStatus.INTERNAL_SERVER_ERROR;

  String toString() => '[response ${statusCode}]';
}

class CommonServer {
  final ServerLogger log;
  final ServerCache cache;

  Analyzer analyzer;
  Compiler compiler;

  CommonServer(String sdkPath, this.log, this.cache) {
    analyzer = new Analyzer(sdkPath);
    compiler = new Compiler(sdkPath);
  }

  Future<ServerResponse> handleAnalyze(String data, [String contentType]) {
    _RequestInput input;

    try {
      input = _parseRequest(data, contentType: contentType);
    } catch (e) {
      return new Future.value(new ServerResponse.badRequest('${e}'));
    }

    Stopwatch watch = new Stopwatch()..start();
    log.info("ANALYZE: ${input.source}");

    try {
      return analyzer.analyze(input.source).then((AnalysisResults results) {
        List issues = results.issues.map((issue) => issue.toMap()).toList();
        String json = JSON.encode(issues);
        int lineCount = input.source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        log.info('PERF: Analyzed ${lineCount} lines of Dart in ${ms}ms.');
        return new ServerResponse.asJson(json);
      }).catchError((e) {
        log.error('Error during analyze: ${e}');
        return new ServerResponse.internalError('${e}');
      });
    } catch (e, st) {
      log.error('Error during analyze: ${e}\n${st}');
      return new Future.value(new ServerResponse.internalError('${e}'));
    }
  }

  Future<ServerResponse> handleCompile(String data, [String contentType]) {
    _RequestInput input;

    try {
      input = _parseRequest(data, contentType: contentType);
    } catch (e) {
      return new Future.value(new ServerResponse.badRequest('${e}'));
    }

    String source = input.source;
    log.info("COMPILE: ${source}");
    String sourceHash = _hashSource(source);

    return checkCache("%%COMPILE:$sourceHash").then((String result) {
      if (result != null) {
        log.info("CACHE: Cache hit for compile");
        return new ServerResponse(HttpStatus.OK, result, _plain);
      } else {
        Stopwatch watch = new Stopwatch()..start();

        return compiler.compile(source).then((CompilationResults results) {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            log.info(
                'PERF: Compiled ${lineCount} lines of Dart into '
                '${outputSize}kb of JavaScript in ${ms}ms.');
            String out = results.getOutput();
            return setCache("%%COMPILE:$sourceHash", out).then((_) {
              return new ServerResponse(HttpStatus.OK, out, _plain);
            });
          } else {
            String errors = results.problems.map(_printCompileProblem).join('\n');
            return new ServerResponse.badRequest(errors);
          }
        }).catchError((e, st) {
          log.error('Error during compile: ${e}\n${st}');
          return new Future.value(
              new ServerResponse.internalError('Error during compile: ${e}'));
        });
      }
    });
  }

  Future<ServerResponse> handleComplete(String data, [String contentType]) {
    _RequestInput input;

    try {
      input = _parseRequest(data, contentType: contentType, requiresOffset: true);
    } catch (e) {
      return new Future.value(new ServerResponse.badRequest('${e}'));
    }

    return new Future.value(
        new ServerResponse.notImplemented('Unimplemented: /api/complete'));
  }

  Future<ServerResponse> handleDocument(String data, [String contentType]) {
    _RequestInput input;

    try {
      input = _parseRequest(data, contentType: contentType, requiresOffset: true);
    } catch (e) {
      return new Future.value(new ServerResponse.badRequest('${e}'));
    }

    Stopwatch watch = new Stopwatch()..start();
    log.info("DOCUMENT: ${input.source}");

    try {
      return analyzer.dartdoc(input.source, input.offset).then((Map docInfo) {
        if (docInfo == null) docInfo = {};
        String json = JSON.encode(docInfo);
        log.info('PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
        return new ServerResponse.asJson(json);
      }).catchError((e, st) {
        log.error('Error during dartdoc: ${e}\n${st}');
        return new ServerResponse.internalError('${e}');
      });
    } catch (e, st) {
      log.error('Error during dartdoc: ${e}\n${st}');
      return new Future.value(new ServerResponse.internalError('${e}'));
    }
  }

  Future<String> checkCache(String query) => cache.get(query);

  Future setCache(String query, String result) =>
      cache.set(query, result, expiration: _standardExpiration);
}

_RequestInput _parseRequest(String data,
    {String contentType, bool requiresOffset: false}) {
  // This could be a plain text post of source code.
  // It could be marked as plain text, but be json encoded.
  // It could be a json post, with source and offset fields.
  // Or it could be application/x-www-form-urlencoded encoded.

  if (data == null || data.isEmpty) {
    throw "No data received";
  }

  if (contentType == null) {
    contentType = _json;
  }
  if (contentType.contains(';')) {
    contentType = contentType.substring(0, contentType.indexOf(';'));
  }
  if (data.startsWith('{"') || data.startsWith("{'")) {
    contentType = _json;
  }

  String source;
  int offset;

  if (contentType == _plain) {
    source = data;
  } else if (contentType == _json) {
    Map m = JSON.decode(data);
    source = m['source'];
    offset = m['offset'];
  } else if (contentType == _urlEncoded) {
    Map m = Uri.splitQueryString(data);
    source = m['source'];
    if (m.containsKey('offset')) {
      offset = int.parse(m['offset'], onError: (str) => null);
    }
  } else {
    // Hmm, an unknown content type.
    source = data;
  }

  if (source == null) throw "'source' parameter missing";
  if (offset == null && requiresOffset) throw "'offset' parameter missing";

  return new _RequestInput(source, offset);
}

class _RequestInput {
  final String source;
  final int offset;

  _RequestInput(this.source, [this.offset]);
}

String _printCompileProblem(CompilationProblem problem) =>
    '[${problem.kind}, line ${problem.line}] ${problem.message}';

String _hashSource(String str) {
  SHA1 sha1 = new SHA1();
  sha1.add(str.codeUnits);
  return CryptoUtils.bytesToHex(sha1.close());
}
