// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rpc/rpc.dart';

import '../version.dart';
import 'analysis_server.dart';
import 'api_classes.dart';
import 'common.dart';
import 'compiler.dart';
import 'flutter_web.dart';
import 'pub.dart';
import 'server_cache.dart';
import 'sdk_manager.dart';

final Duration _standardExpiration = Duration(hours: 1);
final Logger log = Logger('common_server');

abstract class ServerContainer {
  String get version;
}

class SummaryText {
  String text;

  SummaryText.fromString(this.text);
}

@ApiClass(name: 'dartservices', version: 'v1')
class CommonServer {
  final String sdkPath;
  final FlutterWebManager flutterWebManager;
  final ServerContainer container;
  final ServerCache cache;

  Compiler compiler;
  AnalysisServerWrapper analysisServer;
  AnalysisServerWrapper flutterAnalysisServer;

  bool get analysisServersRunning => analysisServer.analysisServer != null &&
    flutterAnalysisServer.analysisServer != null;

  bool _running = false;
  bool get running => _running;

  CommonServer(
    this.sdkPath,
    this.flutterWebManager,
    this.container,
    this.cache,
  ) {
    hierarchicalLoggingEnabled = true;
    log.level = Level.ALL;
  }

  Future<void> init() async {
    log.info('Beginning CommonServer init().');
    analysisServer = AnalysisServerWrapper(sdkPath, flutterWebManager);
    flutterAnalysisServer = AnalysisServerWrapper(
        flutterWebManager.flutterSdk.sdkPath, flutterWebManager);

    compiler =
        Compiler(SdkManager.sdk, SdkManager.flutterSdk, flutterWebManager);

    await analysisServer.init();
    log.info('Dart analysis server initialized.');

    await flutterAnalysisServer.init();
    log.info('Flutter analysis server initialized.');

    unawaited(analysisServer.onExit.then((int code) {
      log.severe('analysisServer exited, code: $code');
      if (code != 0) {
        exit(code);
      }
    }));

    unawaited(flutterAnalysisServer.onExit.then((int code) {
      log.severe('flutterAnalysisServer exited, code: $code');
      if (code != 0) {
        exit(code);
      }
    }));
  }

  Future<void> warmup({bool useHtml = false}) async {
    await flutterWebManager.warmup();
    await compiler.warmup(useHtml: useHtml);
    await analysisServer.warmup(useHtml: useHtml);
    await flutterAnalysisServer.warmup(useHtml: useHtml);
    _running = true;
  }

  Future<void> restart() async {
    log.warning('Restarting CommonServer');
    await shutdown();
    log.info('Analysis Servers shutdown');

    await init();
    await warmup();

    log.warning('Restart complete');
  }

  Future<dynamic> shutdown() {
    _running = false;
    return Future.wait(<Future<dynamic>>[
      analysisServer.shutdown(),
      flutterAnalysisServer.shutdown(),
      compiler.dispose(),
      Future<dynamic>.sync(cache.shutdown)
    ]);
  }

  @ApiMethod(
      method: 'POST',
      path: 'analyze',
      description:
          'Analyze the given Dart source code and return any resulting '
          'analysis errors or warnings.')
  Future<AnalysisResults> analyze(SourceRequest request) {
    return _analyze(request.source);
  }

  @ApiMethod(
      method: 'POST',
      path: 'compile',
      description: 'Compile the given Dart source code and return the '
          'resulting JavaScript; this uses the dart2js compiler.')
  Future<CompileResponse> compile(CompileRequest request) {
    return _compileDart2js(request.source,
        returnSourceMap: request.returnSourceMap ?? false);
  }

  @ApiMethod(
      method: 'POST',
      path: 'compileDDC',
      description: 'Compile the given Dart source code and return the '
          'resulting JavaScript; this uses the DDC compiler.')
  Future<CompileDDCResponse> compileDDC(CompileRequest request) {
    return _compileDDC(request.source);
  }

  @ApiMethod(
      method: 'POST',
      path: 'complete',
      description:
          'Get the valid code completion results for the given offset.')
  Future<CompleteResponse> complete(SourceRequest request) {
    if (request.offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    return _complete(request.source, request.offset);
  }

  @ApiMethod(
      method: 'POST',
      path: 'fixes',
      description: 'Get any quick fixes for the given source code location.')
  Future<FixesResponse> fixes(SourceRequest request) {
    if (request.offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    return _fixes(request.source, request.offset);
  }

  @ApiMethod(
      method: 'POST',
      path: 'assists',
      description: 'Get assists for the given source code location.')
  Future<AssistsResponse> assists(SourceRequest request) {
    if (request.offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    return _assists(request.source, request.offset);
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

  @ApiMethod(
      method: 'POST',
      path: 'document',
      description: 'Return the relevant dartdoc information for the element at '
          'the given offset.')
  Future<DocumentResponse> document(SourceRequest request) {
    return _document(request.source, request.offset);
  }

  @ApiMethod(
      method: 'GET',
      path: 'version',
      description: 'Return the current SDK version for DartServices.')
  Future<VersionResponse> version() =>
      Future<VersionResponse>.value(_version());

  Future<AnalysisResults> _analyze(String source) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    try {
      final watch = Stopwatch()..start();

      final results = await getCorrectAnalysisServer(source).analyze(source);
      final lineCount = source.split('\n').length;
      final ms = watch.elapsedMilliseconds;
      log.info('PERF: Analyzed $lineCount lines of Dart in ${ms}ms.');
      return results;
    } catch (e, st) {
      log.severe('Error during analyze', e, st);
      await restart();
      rethrow;
    }
  }

  Future<CompileResponse> _compileDart2js(
    String source, {
    bool returnSourceMap = false,
  }) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    final sourceHash = _hashSource(source);
    final memCacheKey = '%%COMPILE:v0'
        ':returnSourceMap:$returnSourceMap:source:$sourceHash';

    final result = await checkCache(memCacheKey);
    if (result != null) {
      log.info('CACHE: Cache hit for compileDart2js');
      final resultObj = JsonDecoder().convert(result);
      return CompileResponse(
        resultObj['compiledJS'] as String,
        returnSourceMap ? resultObj['sourceMap'] as String : null,
      );
    }

    log.info('CACHE: MISS for compileDart2js');
    final watch = Stopwatch()..start();

    return compiler
        .compile(source, returnSourceMap: returnSourceMap)
        .then((CompilationResults results) {
      if (results.hasOutput) {
        final lineCount = source.split('\n').length;
        final outputSize = (results.compiledJS.length / 1024).ceil();
        final ms = watch.elapsedMilliseconds;
        log.info('PERF: Compiled $lineCount lines of Dart into '
            '${outputSize}kb of JavaScript in ${ms}ms using dart2js.');
        final sourceMap = returnSourceMap ? results.sourceMap : null;

        final cachedResult = JsonEncoder().convert(<String, String>{
          'compiledJS': results.compiledJS,
          'sourceMap': sourceMap,
        });
        // Don't block on cache set.
        unawaited(setCache(memCacheKey, cachedResult));
        return CompileResponse(results.compiledJS, sourceMap);
      } else {
        final problems = results.problems;
        final errors = problems.map(_printCompileProblem).join('\n');
        throw BadRequestError(errors);
      }
    }).catchError((dynamic e, dynamic st) {
      if (e is! BadRequestError) {
        log.severe('Error during compile (dart2js): $e\n$st');
      }
      throw e;
    });
  }

  Future<CompileDDCResponse> _compileDDC(String source) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    final sourceHash = _hashSource(source);
    final memCacheKey = '%%COMPILE_DDC:v0:source:$sourceHash';

    final result = await checkCache(memCacheKey);
    if (result != null) {
      log.info('CACHE: Cache hit for compileDDC');
      final resultObj = JsonDecoder().convert(result);
      return CompileDDCResponse(
        resultObj['compiledJS'] as String,
        resultObj['modulesBaseUrl'] as String,
      );
    }

    log.info('CACHE: MISS for compileDDC');
    final watch = Stopwatch()..start();

    return compiler.compileDDC(source).then((DDCCompilationResults results) {
      if (results.hasOutput) {
        final lineCount = source.split('\n').length;
        final outputSize = (results.compiledJS.length / 1024).ceil();
        final ms = watch.elapsedMilliseconds;
        log.info('PERF: Compiled $lineCount lines of Dart into '
            '${outputSize}kb of JavaScript in ${ms}ms using DDC.');

        final cachedResult = JsonEncoder().convert(<String, String>{
          'compiledJS': results.compiledJS,
          'modulesBaseUrl': results.modulesBaseUrl,
        });
        // Don't block on cache set.
        unawaited(setCache(memCacheKey, cachedResult));
        return CompileDDCResponse(results.compiledJS, results.modulesBaseUrl);
      } else {
        final problems = results.problems;
        final errors = problems.map(_printCompileProblem).join('\n');
        throw BadRequestError(errors);
      }
    }).catchError((dynamic e, dynamic st) {
      if (e is! BadRequestError) {
        log.severe('Error during compile (DDC): $e\n$st');
      }
      throw e;
    });
  }

  Future<DocumentResponse> _document(String source, int offset) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    final watch = Stopwatch()..start();
    try {
      var docInfo =
          await getCorrectAnalysisServer(source).dartdoc(source, offset);
      docInfo ??= <String, String>{};
      log.info('PERF: Computed dartdoc in ${watch.elapsedMilliseconds}ms.');
      return DocumentResponse(docInfo);
    } catch (e, st) {
      log.severe('Error during dartdoc', e, st);
      await restart();
      rethrow;
    }
  }

  VersionResponse _version() => VersionResponse(
      sdkVersion: SdkManager.sdk.version,
      sdkVersionFull: SdkManager.sdk.versionFull,
      runtimeVersion: vmVersion,
      servicesVersion: servicesVersion,
      appEngineVersion: container.version);

  Future<CompleteResponse> _complete(String source, int offset) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    final watch = Stopwatch()..start();
    try {
      final response =
          await getCorrectAnalysisServer(source).complete(source, offset);
      log.info('PERF: Computed completions in ${watch.elapsedMilliseconds}ms.');
      return response;
    } catch (e, st) {
      log.severe('Error during _complete', e, st);
      await restart();
      rethrow;
    }
  }

  Future<FixesResponse> _fixes(String source, int offset) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    final watch = Stopwatch()..start();
    final response =
        await getCorrectAnalysisServer(source).getFixes(source, offset);
    log.info('PERF: Computed fixes in ${watch.elapsedMilliseconds}ms.');
    return response;
  }

  Future<AssistsResponse> _assists(String source, int offset) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }
    if (offset == null) {
      throw BadRequestError('Missing parameter: \'offset\'');
    }

    await _checkPackageReferencesInitFlutterWeb(source);

    final watch = Stopwatch()..start();
    final response =
        await getCorrectAnalysisServer(source).getAssists(source, offset);
    log.info('PERF: Computed assists in ${watch.elapsedMilliseconds}ms.');
    return response;
  }

  Future<FormatResponse> _format(String source, {int offset}) async {
    if (source == null) {
      throw BadRequestError('Missing parameter: \'source\'');
    }
    offset ??= 0;

    final watch = Stopwatch()..start();

    final response =
        await getCorrectAnalysisServer(source).format(source, offset);
    log.info('PERF: Computed format in ${watch.elapsedMilliseconds}ms.');
    return response;
  }

  Future<String> checkCache(String query) => cache.get(query);

  Future<void> setCache(String query, String result) =>
      cache.set(query, result, expiration: _standardExpiration);

  /// Check that the set of packages referenced is valid.
  ///
  /// If there are uses of package:flutter, ensure that support there is
  /// initialized.
  Future<void> _checkPackageReferencesInitFlutterWeb(String source) async {
    final imports = getAllImportsFor(source);

    if (flutterWebManager.hasUnsupportedImport(imports)) {
      throw BadRequestError(
          'Unsupported input: ${flutterWebManager.getUnsupportedImport(imports)}');
    }

    if (flutterWebManager.usesFlutterWeb(imports)) {
      try {
        await flutterWebManager.initFlutterWeb();
      } catch (e) {
        log.warning('unable to init package:flutter: $e');
        return;
      }
    }
  }

  AnalysisServerWrapper getCorrectAnalysisServer(String source) {
    final imports = getAllImportsFor(source);
    return flutterWebManager.usesFlutterWeb(imports)
        ? flutterAnalysisServer
        : analysisServer;
  }
}

String _printCompileProblem(CompilationProblem problem) => problem.message;

String _hashSource(String str) {
  return sha1.convert(str.codeUnits).toString();
}
