// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:rpc/rpc.dart';

import 'analyzer.dart';
import 'compiler.dart';

final Duration _standardExpiration = new Duration(hours: 1);

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

class SourceRequest {
  @ApiProperty(required: true)
  String source;
  int offset;
}

class CompileResponse {
  final String result;

  CompileResponse(this.result);
}

class CompleteResponse {
  // TODO: not yet implemented.
}

class DocumentResponse {
  final Map<String, String> info;

  DocumentResponse(this.info);
}

@ApiClass(name: 'dartservices', version: 'v1')
class CommonServer {
  final ServerLogger log;
  final ServerCache cache;

  Analyzer analyzer;
  Compiler compiler;

  CommonServer(String sdkPath, this.log, this.cache) {
    analyzer = new Analyzer(sdkPath);
    compiler = new Compiler(sdkPath);
  }

  @ApiMethod(method: 'POST', path: 'analyze')
  Future<AnalysisResults> analyze(SourceRequest request) {
    return _analyze(request.source);
  }

  @ApiMethod(method: 'GET', path: 'analyze')
  Future<AnalysisResults> analyzeGet({String source}) {
    return _analyze(source);
  }

  @ApiMethod(method: 'POST', path: 'compile')
  Future<CompileResponse> compile(SourceRequest request) {
    return _compile(request.source);
  }

  @ApiMethod(method: 'GET', path: 'compile')
  Future<CompileResponse> compileGet({String source}) {
    return _compile(source);
  }

  @ApiMethod(method: 'POST', path: 'complete')
  Future<CompleteResponse> complete(SourceRequest request) {
    if (request.offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }
    throw new RpcError(HttpStatus.NOT_IMPLEMENTED, 'Not Implemented',
                       '\'complete\' method not implemented.');
  }

  @ApiMethod(method: 'GET', path: 'complete')
  Future<CompleteResponse> completeGet({String source, int offset}) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }
    throw new RpcError(HttpStatus.NOT_IMPLEMENTED, 'Not Implemented',
                       '\'complete\' method not implemented.');
  }

  @ApiMethod(method: 'POST', path: 'document')
  Future<DocumentResponse> document(SourceRequest request) {
    return _document(request.source, request.offset);
  }

  @ApiMethod(method: 'GET', path: 'document')
  Future<DocumentResponse> documentGet({String source, int offset}) {
    return _document(source, offset);
  }

  Future<AnalysisResults> _analyze(String source) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    Stopwatch watch = new Stopwatch()..start();
    log.info("ANALYZE: $source");

    try {
      return analyzer.analyze(source).then((AnalysisResults results) {
        int lineCount = source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        log.info('PERF: Analyzed ${lineCount} lines of Dart in ${ms}ms.');
        return results;
      }).catchError((e) {
        log.error('Error during analyze: ${e}');
        throw e;
      });
    } catch (e, st) {
      log.error('Error during analyze: ${e}\n${st}');
      throw e;
    }
  }

  Future<CompileResponse> _compile(String source) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    log.info("COMPILE: ${source}");
    String sourceHash = _hashSource(source);
    
    // TODO(lukechurch): Remove this hack after
    // https://github.com/dart-lang/rpc/issues/15 lands
    bool supressCache = source.trim().endsWith("/** <Supress-Memcache> **/");

    return checkCache("%%COMPILE:$sourceHash").then((String result) {
      if (!supressCache && result != null) {
        log.info("CACHE: Cache hit for compile");
        return new CompileResponse(result);
      } else {
        log.info("CACHE: MISS, forced: $supressCache");
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
              return new CompileResponse(out);
            });
          } else {
            String errors =
                results.problems.map(_printCompileProblem).join('\n');
            throw new BadRequestError(
                'Compilation failed with errors: $errors');
          }
        }).catchError((e, st) {
          log.error('Error during compile: ${e}\n${st}');
          throw e;
        });
      }
    });
  }

  Future<DocumentResponse> _document(String source, int offset) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }
    Stopwatch watch = new Stopwatch()..start();
    log.info("DOCUMENT: ${source}");

    try {
      return analyzer.dartdoc(source, offset)
          .then((Map<String, String> docInfo) {
            if (docInfo == null) docInfo = {};
            log.info(
                'PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
            return new DocumentResponse(docInfo);
          }).catchError((e, st) {
            log.error('Error during dartdoc: ${e}\n${st}');
            throw e;
          });
    } catch (e, st) {
      log.error('Error during dartdoc: ${e}\n${st}');
      throw e;
    }
  }

  Future<String> checkCache(String query) => cache.get(query);

  Future setCache(String query, String result) =>
      cache.set(query, result, expiration: _standardExpiration);
}

String _printCompileProblem(CompilationProblem problem) =>
    '[${problem.kind}, line ${problem.line}] ${problem.message}';

String _hashSource(String str) {
  SHA1 sha1 = new SHA1();
  sha1.add(str.codeUnits);
  return CryptoUtils.bytesToHex(sha1.close());
}
