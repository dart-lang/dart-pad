// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server;

import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';

import 'api_classes.dart';
import 'analysis_server.dart';
import 'analyzer.dart';
import 'common.dart';
import 'compiler.dart';
import 'pub.dart';
import '../version.dart';

final Duration _standardExpiration = new Duration(hours: 1);
final Logger _logger = new Logger('common_server');

/// Toggle to on to enable `package:` support.
final bool enablePackages = false;

abstract class ServerCache {
  Future<String> get(String key);
  Future set(String key, String value, {Duration expiration});
  Future remove(String key);
}

abstract class ServerContainer {
  String get version;
}

/**
 * Define a seperate class for source recording to provide a clearly
 * defined schema
 */
abstract class SourceRequestRecorder {
  Future record(String verb, String source, [int offset]);
}

abstract class PersistentCounter {
  Future increment(String name, {int increment: 1});
  Future<int> getTotal(String name);
}

@ApiClass(name: 'dartservices', version: 'v1')
class CommonServer {
  final ServerContainer container;
  final ServerCache cache;
  final SourceRequestRecorder srcRequestRecorder;
  final PersistentCounter counter;

  Pub pub;
  Analyzer analyzer;
  Compiler compiler;
  AnalysisServerWrapper analysisServer;

  CommonServer(String sdkPath,
      this.container,
      this.cache,
      this.srcRequestRecorder,
      this.counter) {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;

    pub = enablePackages ? new Pub() : new Pub.mock();

    analyzer = new Analyzer(sdkPath);
    compiler = new Compiler(sdkPath, pub);
    analysisServer = new AnalysisServerWrapper(sdkPath);
  }

  Future warmup([bool useHtml = false]) async {
    await analyzer.warmup(useHtml);
    await compiler.warmup(useHtml);
    await analysisServer.warmup(useHtml);
  }

  Future shutdown() => analysisServer.shutdown();

  @ApiMethod(method: 'GET', path: 'counter')
  Future<CounterResponse> counterGet({String name}) {
    return counter.getTotal(name).then((total) {
      return new CounterResponse.fromCount(total);
    });
  }

  @ApiMethod(
      method: 'POST',
      path: 'analyze',
      description: 'Analyze the given Dart source code and return any resulting '
        'analysis errors or warnings.')
  Future<AnalysisResults> analyze(SourceRequest request) {
    return _analyze(request.source);
  }

  @ApiMethod(method: 'GET', path: 'analyze')
  Future<AnalysisResults> analyzeGet({String source}) {
    return _analyze(source);
  }

  @ApiMethod(
      method: 'POST',
      path: 'compile',
      description: 'Compile the given Dart source code and return the resulting '
        'JavaScript.')
  Future<CompileResponse> compile(SourceRequest request) {
    return _compile(request.source);
  }

  @ApiMethod(method: 'GET', path: 'compile')
  Future<CompileResponse> compileGet({String source}) {
    return _compile(source);
  }

  @ApiMethod(
      method: 'POST',
      path: 'complete',
      description: 'Get the valid code completion results for the given offset.')
  Future<CompleteResponse> complete(SourceRequest request) {
    if (request.offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _complete(request.source, request.offset);
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

  @ApiMethod(
      method: 'POST',
      path: 'fixes',
      description: 'Get any quick fixes for the given source code location.')
  Future<FixesResponse> fixes(SourceRequest request) {
    if (request.offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _fixes(request.source, request.offset);
  }

  @ApiMethod(method: 'GET', path: 'fixes')
  Future<FixesResponse> fixesGet({String source, int offset}) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _fixes(source, offset);
  }

  @ApiMethod(
      method: 'POST',
      path: 'format',
      description: 'Format the given Dart source code and return the results. '
        'If an offset is supplied in the request, the new position for that '
        'offset in the formatted code will be returned.')
  Future<FormatResponse> format(SourceRequest request) {
    return _format(request.source, offset: request.offset);
  }

  @ApiMethod(method: 'GET', path: 'format')
  Future<FormatResponse> formatGet({String source, int offset}) {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }

    return _format(source, offset: offset);
  }

  @ApiMethod(
      method: 'POST',
      path: 'document',
      description: 'Return the relevant dartdoc information for the element at '
        'the given offset.')
  Future<DocumentResponse> document(SourceRequest request) {
    return _document(request.source, request.offset);
  }

  @ApiMethod(method: 'GET', path: 'document')
  Future<DocumentResponse> documentGet({String source, int offset}) {
    return _document(source, offset);
  }

  @ApiMethod(
      method: 'GET',
      path: 'version',
      description: 'Return the current SDK version for DartPad.')
  Future<VersionResponse> version() => new Future.value(_version());

  Future<AnalysisResults> _analyze(String source) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    Stopwatch watch = new Stopwatch()..start();
    srcRequestRecorder.record("ANALYZE", source);
    try {
      return analyzer.analyze(source).then((AnalysisResults results) async {
        int lineCount = source.split('\n').length;
        int ms = watch.elapsedMilliseconds;
        _logger.info('PERF: Analyzed ${lineCount} lines of Dart in ${ms}ms.');
        counter.increment("Analyses");
        counter.increment("Analyzed-Lines", increment: lineCount);
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

  Future<CompileResponse> _compile(String source) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    srcRequestRecorder.record("COMPILE", source);
    String sourceHash = _hashSource(source);

    // TODO(lukechurch): Remove this hack after
    // https://github.com/dart-lang/rpc/issues/15 lands
    var trimSrc = source.trim();
    bool suppressCache = trimSrc.endsWith("/** Supress-Memcache **/") ||
        trimSrc.endsWith("/** Suppress-Memcache **/");

    return checkCache("%%COMPILE:$sourceHash").then((String result) {
      if (!suppressCache && result != null) {
        _logger.info("CACHE: Cache hit for compile");
        return new CompileResponse.fromResponse(result);
      } else {
        _logger.info("CACHE: MISS, forced: $suppressCache");
        Stopwatch watch = new Stopwatch()..start();

        return compiler.compile(source).then((CompilationResults results) async {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            _logger.info(
              'PERF: Compiled ${lineCount} lines of Dart into '
              '${outputSize}kb of JavaScript in ${ms}ms.');
            counter.increment("Compilations");
            counter.increment("Compiled-Lines", increment: lineCount);
            String out = results.getOutput();
            return setCache("%%COMPILE:$sourceHash", out).then((_) {
              return new CompileResponse.fromResponse(out);
            });
          } else {
            List problems = _filterCompileProblems(results.problems);
            if (problems.isEmpty) problems = results.problems;
            String errors = problems.map(_printCompileProblem).join('\n');
            throw new BadRequestError(errors);
          }
        }).catchError((e, st) {
          _logger.severe('Error during compile: ${e}\n${st}');
          throw e;
        });
      }
    });
  }

  Future<DocumentResponse> _document(String source, int offset) async {
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
        .then((Map<String, String> docInfo) async {
          if (docInfo == null) docInfo = {};
          _logger.info(
            'PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
          counter.increment("DartDocs");
          return new DocumentResponse.fromInfo(docInfo);
        }).catchError((e, st) {
          _logger.severe('Error during dartdoc: ${e}\n${st}');
          throw e;
        });
    } catch (e, st) {
      _logger.severe('Error during dartdoc: ${e}\n${st}');
      throw e;
    }
  }

  VersionResponse _version() => new VersionResponse.from(
      sdkVersion: compiler.version,
      runtimeVersion: vmVersion,
      servicesVersion: servicesVersion,
      appEngineVersion: "1.0");

  Future<CompleteResponse> _complete(String source, int offset) async {
    srcRequestRecorder.record("COMPLETE", source, offset);
    counter.increment("Completions");
    return analysisServer.complete(source, offset);
  }

  Future<FixesResponse> _fixes(String source, int offset) async {
      srcRequestRecorder.record("FIX", source, offset);
      counter.increment("Fixes");
      return analysisServer.getFixes(source, offset);
    }

  Future<FormatResponse> _format(String source, {int offset}) async {
    if (offset == null) offset = 0;
    srcRequestRecorder.record("FORMAT", source, offset);
    counter.increment("Formats");

    // Guard against trying to format code with errors.
    AnalysisResults analysisResults = await analyzer.analyze(source);

    if (analysisResults.issues.where(
      (issue) => issue.kind == "error").length > 0) {
      return new FormatResponse.fromCode(source, offset);
    }
    return analysisServer.format(source, offset);
  }

  Future<String> checkCache(String query) => cache.get(query);

  Future setCache(String query, String result) =>
      cache.set(query, result, expiration: _standardExpiration);
}

List<CompilationProblem> _filterCompileProblems(List<CompilationProblem> problems) {
  return problems.where((p) => !p.isHint && p.isOnCompileTarget).toList();
}

String _printCompileProblem(CompilationProblem problem) {
  if (problem.isOnCompileTarget) {
    return '[${problem.kind} on line ${problem.line}] ${problem.message}';
  } else {
    return '[${problem.kind}] ${problem.message}';
  }
}

String _hashSource(String str) {
  SHA1 sha1 = new SHA1();
  sha1.add(str.codeUnits);
  return CryptoUtils.bytesToHex(sha1.close());
}
