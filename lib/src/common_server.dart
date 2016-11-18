// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';

import '../version.dart';
import 'analysis_server.dart';
import 'analyzer.dart';
import 'api_classes.dart';
import 'common.dart';
import 'compiler.dart';
import 'pub.dart';
import 'summarize.dart';

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

class SummaryText {
  String text;
  SummaryText.fromString(String this.text);
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
  Analyzer strongModeAnalyzer;
  Analyzer analyzer;

  Compiler compiler;
  AnalysisServerWrapper analysisServer;

  CommonServer(String sdkPath, this.container, this.cache,
      this.srcRequestRecorder, this.counter) {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;

    pub = enablePackages ? new Pub() : new Pub.mock();
    strongModeAnalyzer = new Analyzer(sdkPath, strongMode: true);
    analyzer = new Analyzer(sdkPath);
    compiler = new Compiler(sdkPath, pub);
    analysisServer = new AnalysisServerWrapper(sdkPath);
  }

  Future warmup([bool useHtml = false]) async {
    await analyzer.warmup(useHtml);
    await strongModeAnalyzer.warmup(useHtml);
    await compiler.warmup(useHtml);
    await analysisServer.warmup(useHtml);
  }

  Future shutdown() => analysisServer.shutdown();

  @ApiMethod(method: 'GET', path: 'counter')
  Future<CounterResponse> counterGet({String name}) {
    return counter.getTotal(name).then((total) {
      return new CounterResponse(total);
    });
  }

  @ApiMethod(
      method: 'POST',
      path: 'analyze',
      description:
          'Analyze the given Dart source code and return any resulting '
          'analysis errors or warnings.')
  Future<AnalysisResults> analyze(SourceRequest request) {
    return _analyze(request.source, request.strongMode);
  }

  @ApiMethod(
      method: 'POST',
      path: 'analyzeMulti',
      description:
          'Analyze the given Dart source code and return any resulting '
          'analysis errors or warnings.')
  Future<AnalysisResults> analyzeMulti(SourcesRequest request) {
    return _analyzeMulti(request.sources, request.strongMode);
  }

  @ApiMethod(
      method: 'POST',
      path: 'summarize',
      description:
          'Summarize the given Dart source code and return any resulting '
          'analysis errors or warnings.')
  Future<SummaryText> summarize(SourcesRequest request) {
    return _summarize(request.sources['dart'], request.sources['css'],
        request.sources['html']);
  }

  @ApiMethod(method: 'GET', path: 'analyze')
  Future<AnalysisResults> analyzeGet({String source, bool strongMode: false}) {
    return _analyze(source, strongMode);
  }

  @ApiMethod(
      method: 'POST',
      path: 'compile',
      description: 'Compile the given Dart source code and return the '
          'resulting JavaScript.')
  Future<CompileResponse> compile(CompileRequest request) =>
      _compile(request.source,
          useCheckedMode: request.useCheckedMode,
          returnSourceMap: request.returnSourceMap);

  @ApiMethod(method: 'GET', path: 'compile')
  Future<CompileResponse> compileGet({String source}) => _compile(source);

  @ApiMethod(
      method: 'POST',
      path: 'complete',
      description:
          'Get the valid code completion results for the given offset.')
  Future<CompleteResponse> complete(SourceRequest request) {
    if (request.offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _complete(request.source, request.offset);
  }

  @ApiMethod(
      method: 'POST',
      path: 'completeMulti',
      description:
          'Get the valid code completion results for the given offset.')
  Future<CompleteResponse> completeMulti(SourcesRequest request) {
    if (request.location == null) {
      throw new BadRequestError('Missing parameter: \'location\'');
    }

    return _completeMulti(
        request.sources, request.location.sourceName, request.location.offset);
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

  @ApiMethod(
      method: 'POST',
      path: 'fixesMulti',
      description: 'Get any quick fixes for the given source code location.')
  Future<FixesResponse> fixesMulti(SourcesRequest request) {
    if (request.location.sourceName == null) {
      throw new BadRequestError('Missing parameter: \'fullName\'');
    }
    if (request.location.offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _fixesMulti(
        request.sources, request.location.sourceName, request.location.offset);
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
      description: 'Return the current SDK version for DartServices.')
  Future<VersionResponse> version() => new Future.value(_version());

  Future<AnalysisResults> _analyze(String source, bool strongMode) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    return _analyzeMulti({"main.dart": source}, strongMode);
  }

  Future<SummaryText> _summarize(String dart, String html, String css) async {
    if (dart == null || html == null || css == null) {
      throw new BadRequestError('Missing core source parameter.');
    }
    String sourcesJson =
        new JsonEncoder().convert({"dart": dart, "html": html, "css": css});
    _logger.info("About to summarize: ${_hashSource(sourcesJson)}");

    SummaryText summaryString =
        await _analyzeMulti({"main.dart": dart}, false).then((result) {
      Summarizer summarizer =
          new Summarizer(dart: dart, html: html, css: css, analysis: result);
      return new SummaryText.fromString(summarizer.returnAsSimpleSummary());
    });
    return new Future.value(summaryString);
  }

  Future<AnalysisResults> _analyzeMulti(Map<String, String> sources,
    bool strongMode) async {
    if (sources == null) {
      throw new BadRequestError('Missing parameter: \'sources\'');
    }
    strongMode ??= false;

    Stopwatch watch = new Stopwatch()..start();
    String sourcesJson = new JsonEncoder().convert(sources);
    srcRequestRecorder.record("ANALYZE-v2-$strongMode", sourcesJson);
    _logger.info("About to ANALYZE-v1: ${_hashSource(sourcesJson)}");

    // Select the right analyzer
    Analyzer selectedAnalyzer = strongMode ? strongModeAnalyzer : analyzer;
    try {
      return selectedAnalyzer
          .analyzeMulti(sources)
          .then((AnalysisResults results) async {
        int lineCount = 0;
        sources.values
            .forEach((String source) => lineCount += source.split('\n').length);
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

  Future<CompileResponse> _compile(String source,
      {bool useCheckedMode, bool returnSourceMap}) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (useCheckedMode == null) useCheckedMode = false;
    if (returnSourceMap == null) returnSourceMap = false;

    srcRequestRecorder.record("COMPILE", source);
    String sourceHash = _hashSource(source);
    _logger.info("About to COMPILE: ${sourceHash}");

    // TODO(lukechurch): Remove this hack after
    // https://github.com/dart-lang/rpc/issues/15 lands
    var trimSrc = source.trim();
    bool suppressCache = trimSrc.endsWith("/** Supress-Memcache **/") ||
        trimSrc.endsWith("/** Suppress-Memcache **/");

    String memCacheKey = "%%COMPILE:v0:useCheckedMode:$useCheckedMode"
        "returnSourceMap:$returnSourceMap:"
        "source:$sourceHash";

    return checkCache(memCacheKey).then((String result) {
      if (!suppressCache && result != null) {
        _logger.info("CACHE: Cache hit for compile");
        var resultObj = new JsonDecoder().convert(result);
        return new CompileResponse(resultObj["output"],
            returnSourceMap ? resultObj["sourceMap"] : null);
      } else {
        _logger.info("CACHE: MISS, forced: $suppressCache");
        Stopwatch watch = new Stopwatch()..start();

        return compiler
            .compile(source,
                useCheckedMode: useCheckedMode,
                returnSourceMap: returnSourceMap)
            .then((CompilationResults results) async {
          if (results.hasOutput) {
            int lineCount = source.split('\n').length;
            int outputSize = (results.getOutput().length + 512) ~/ 1024;
            int ms = watch.elapsedMilliseconds;
            _logger.info('PERF: Compiled ${lineCount} lines of Dart into '
                '${outputSize}kb of JavaScript in ${ms}ms.');
            counter.increment("Compilations");
            counter.increment("Compiled-Lines", increment: lineCount);
            String out = results.getOutput();
            String sourceMap = returnSourceMap ? results.getSourceMap() : null;

            String cachedResult = new JsonEncoder()
                .convert({"output": out, "sourceMap": sourceMap});
            await setCache(memCacheKey, cachedResult);
            return new CompileResponse(out, sourceMap);
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
    _logger.info("About to DOCUMENT: ${_hashSource(source)}");
    try {
      return analyzer
          .dartdoc(source, offset)
          .then((Map<String, String> docInfo) async {
        if (docInfo == null) docInfo = {};
        _logger
            .info('PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
        counter.increment("DartDocs");
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

  VersionResponse _version() => new VersionResponse(
      sdkVersion: compiler.version,
      sdkVersionFull: compiler.versionFull,
      runtimeVersion: vmVersion,
      servicesVersion: servicesVersion,
      appEngineVersion: container.version);

  Future<CompleteResponse> _complete(String source, int offset) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _completeMulti({"main.dart": source}, "main.dart", offset);
  }

  Future<CompleteResponse> _completeMulti(
      Map<String, String> sources, String sourceName, int offset) async {
    if (sources == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (sourceName == null) {
      throw new BadRequestError('Missing parameter: \'name\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    Stopwatch watch = new Stopwatch()..start();
    String sourceJson = new JsonEncoder().convert(sources);
    srcRequestRecorder.record("COMPLETE-v1", sourceJson, offset);
    _logger.info("About to COMPLETE-v1: ${_hashSource(sourceJson)}");

    counter.increment("Completions");
    var response = await analysisServer.completeMulti(
        sources,
        new Location()
          ..sourceName = sourceName
          ..offset = offset);
    _logger
        .info('PERF: Computed completions in ${watch.elapsedMilliseconds}ms.');
    return response;
  }

  Future<FixesResponse> _fixes(String source, int offset) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    return _fixesMulti({"main.dart": source}, "main.dart", offset);
  }

  Future<FixesResponse> _fixesMulti(
      Map<String, String> sources, String sourceName, int offset) async {
    if (sources == null) {
      throw new BadRequestError('Missing parameter: \'sources\'');
    }
    if (offset == null) {
      throw new BadRequestError('Missing parameter: \'offset\'');
    }

    Stopwatch watch = new Stopwatch()..start();
    String sourceJson = new JsonEncoder().convert(sources);
    srcRequestRecorder.record("FIX-v1", sourceJson, offset);
    _logger.info("About to FIX-v1: ${_hashSource(sourceJson)}");

    counter.increment("Fixes");
    var response = await analysisServer.getFixesMulti(
        sources,
        new Location()
          ..sourceName = sourceName
          ..offset = offset);
    _logger.info('PERF: Computed fixes in ${watch.elapsedMilliseconds}ms.');
    return response;
  }

  Future<FormatResponse> _format(String source, {int offset}) async {
    if (source == null) {
      throw new BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) offset = 0;
    Stopwatch watch = new Stopwatch()..start();
    srcRequestRecorder.record("FORMAT", source, offset);
    _logger.info("About to FORMAT: ${_hashSource(source)}");
    counter.increment("Formats");

    // Guard against trying to format code with errors.
    AnalysisResults analysisResults = await analyzer.analyze(source);

    var response;
    if (analysisResults.issues.where((issue) => issue.kind == "error").length >
        0) {
      response = new FormatResponse(source, offset);
      _logger.info('PERF: Format aborted due to analysis errors in'
          ' ${watch.elapsedMilliseconds}ms.');
      return response;
    }
    response = await analysisServer.format(source, offset);
    _logger.info('PERF: Computed format in ${watch.elapsedMilliseconds}ms.');
    return response;
  }

  Future<String> checkCache(String query) => cache.get(query);

  Future setCache(String query, String result) =>
      cache.set(query, result, expiration: _standardExpiration);
}

List<CompilationProblem> _filterCompileProblems(
    List<CompilationProblem> problems) {
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
  return sha1.convert(str.codeUnits).toString();
}
