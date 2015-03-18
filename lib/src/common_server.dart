// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server;

import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';

import 'analyzer.dart';
import 'compiler.dart';

import 'completer_driver.dart' as completer;

final Duration _standardExpiration = new Duration(hours: 1);
final Logger _logger = new Logger('common_server');

abstract class ServerCache {
  Future<String> get(String key);
  Future set(String key, String value, {Duration expiration});
  Future remove(String key);
}

/**
 * Define a seperate class for source recording to provide a clearly
 * defined schema
 */
abstract class SourceRequestRecorder {
  Future record(String verb, String source, [int offset]);
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
  String result;

  CompleteResponse(List<String> completions) {
    result = completions.join(",");
  }
}

class DocumentResponse {
  final Map<String, String> info;

  DocumentResponse(this.info);
}

@ApiClass(name: 'dartservices', version: 'v1')
class CommonServer {
  final ServerCache cache;
  final SourceRequestRecorder srcRequestRecorder;

  Analyzer analyzer;
  Compiler compiler;

  CommonServer(String sdkPath, this.cache, this.srcRequestRecorder) {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;
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

    var response = _complete(request.source, request.offset);

    print ("returning: $response");

    return response;
  }

  @ApiMethod(method: 'GET', path: 'complete')
  Future<CompleteResponse> completeGet({String source, int offset}) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _complete(source, offset);
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
    srcRequestRecorder.record("ANALYZE", source);
    try {
      return analyzer.analyze(source).then((AnalysisResults results) {
        int lineCount = source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        _logger.info('PERF: Analyzed ${lineCount} lines of Dart in ${ms}ms.');
        return results;
      }).catchError((e) {
        _logger.severe('Error during analyze: ${e}');
        throw e;
      });
    } catch (e, st) {
      _logger.severe('Error during analyze: ${e}\n${st}');
      throw e;
    }
  }

  Future<CompileResponse> _compile(String source) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    srcRequestRecorder.record("COMPILE", source);
    String sourceHash = _hashSource(source);

    // TODO(lukechurch): Remove this hack after
    // https://github.com/dart-lang/rpc/issues/15 lands
    bool supressCache = source.trim().endsWith("/** Supress-Memcache **/");

    return checkCache("%%COMPILE:$sourceHash").then((String result) {
      if (!supressCache && result != null) {
        _logger.info("CACHE: Cache hit for compile");
        return new CompileResponse(result);
      } else {
        _logger.info("CACHE: MISS, forced: $supressCache");
        Stopwatch watch = new Stopwatch()..start();

        return compiler.compile(source).then((CompilationResults results) {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            _logger.info(
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
              'Compilation of $sourceHash failed with errors: $errors');
          }
        }).catchError((e, st) {
          _logger.severe('Error during compile: ${e}\n${st}');
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
    srcRequestRecorder.record("DOCUMENT", source, offset);
    try {
      return analyzer.dartdoc(source, offset)
        .then((Map<String, String> docInfo) {
          if (docInfo == null) docInfo = {};
          _logger.info(
            'PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
          return new DocumentResponse(docInfo);
        }).catchError((e, st) {
          _logger.severe('Error during dartdoc: ${e}\n${st}');
          throw e;
        });
    } catch (e, st) {
      _logger.severe('Error during dartdoc: ${e}\n${st}');
      throw e;
    }
  }

  Future<CompleteResponse> _complete(String source, int offset) {
    srcRequestRecorder.record("COMPILE", source, offset);
    return completer.ensureSetup().then((_) {
      return completer.completeSyncy(source, offset).then((var results) {
        results['results']
          .sort((x, y) => -1 * x['relevance'].compareTo(y['relevance']));
        var completions = results['results'].map((r) => r['completion']);
        return new CompleteResponse(completions);
      });
    });
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
