// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_impl;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';

import '../version.dart';
import 'analysis_servers.dart';
import 'common.dart';
import 'compiler.dart';
import 'protos/dart_services.pb.dart' as proto;
import 'sdk_manager.dart';
import 'server_cache.dart';

const Duration _standardExpiration = Duration(hours: 1);
final Logger log = Logger('common_server');

class BadRequest implements Exception {
  String cause;

  BadRequest(this.cause);
}

abstract class ServerContainer {
  String get version;
}

class CommonServerImplProxy implements CommonServerImpl {
  const CommonServerImplProxy(
      this._wrapped, this._darkLaunch, this._proxyTarget);
  final CommonServerImpl _wrapped;
  final String _proxyTarget;
  final bool _darkLaunch;

  @override
  Future<String> _checkCache(String query) => _wrapped._checkCache(query);

  @override
  Future<proto.CompileDDCResponse> _compileDDC(String source) =>
      _wrapped._compileDDC(source);

  @override
  Future<proto.CompileResponse> _compileDart2js(String source,
          {bool returnSourceMap = false}) =>
      _wrapped._compileDart2js(source, returnSourceMap: returnSourceMap);

  @override
  Future<void> _setCache(String query, String result) =>
      _wrapped._setCache(query, result);

  @override
  bool get analysisServersRunning => _wrapped.analysisServersRunning;

  @override
  Future<proto.AnalysisResults> analyze(proto.SourceRequest request) =>
      _wrapped.analyze(request);

  @override
  Future<proto.AssistsResponse> assists(proto.SourceRequest request) =>
      _wrapped.assists(request);

  @override
  Future<proto.CompileResponse> compile(proto.CompileRequest request) {
    final url = '${_proxyTarget}api/dartservices/v2/compile';
    final proxyResponse = http.post(url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: _jsonEncoder.convert(request.toProto3Json()));
    if (_darkLaunch) {
      proxyResponse.then((response) {
        log.info(
            'compile: Proxied request returned status code: ${response.statusCode}');
      });
      return _wrapped.compile(request);
    } else {
      return proxyResponse.then((response) async {
        if (response.statusCode == 200) {
          return proto.CompileResponse.create()
            ..mergeFromProto3Json(JsonDecoder().convert(response.body));
        } else {
          final err = proto.BadRequest.create()
            ..mergeFromProto3Json(JsonDecoder().convert(response.body));
          throw BadRequest(err.error.message);
        }
      });
    }
  }

  @override
  Future<proto.CompileDDCResponse> compileDDC(proto.CompileDDCRequest request) {
    final url = '${_proxyTarget}api/dartservices/v2/compileDDC';
    final proxyResponse = http.post(url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: _jsonEncoder.convert(request.toProto3Json()));
    if (_darkLaunch) {
      proxyResponse.then((response) {
        log.info(
            'compileDDC: Proxied request returned status code: ${response.statusCode}');
      });
      return _wrapped.compileDDC(request);
    } else {
      return proxyResponse.then((response) async {
        if (response.statusCode == 200) {
          return proto.CompileDDCResponse.create()
            ..mergeFromProto3Json(JsonDecoder().convert(response.body));
        } else {
          final err = proto.BadRequest.create()
            ..mergeFromProto3Json(JsonDecoder().convert(response.body));
          throw BadRequest(err.error.message);
        }
      });
    }
  }

  @override
  Future<proto.CompleteResponse> complete(proto.SourceRequest request) =>
      _wrapped.complete(request);

  @override
  Future<proto.DocumentResponse> document(proto.SourceRequest request) =>
      _wrapped.document(request);

  @override
  Future<proto.FixesResponse> fixes(proto.SourceRequest request) =>
      _wrapped.fixes(request);

  @override
  Future<proto.FormatResponse> format(proto.SourceRequest request) =>
      _wrapped.format(request);

  @override
  Future<void> init() => _wrapped.init();

  @override
  bool get isHealthy => _wrapped.isHealthy;

  @override
  bool get isRestarting => _wrapped.isRestarting;

  @override
  Future shutdown() => _wrapped.shutdown();

  @override
  Future<proto.VersionResponse> version(proto.VersionRequest request) =>
      _wrapped.version(request);

  @override
  AnalysisServersWrapper get _analysisServers => _wrapped._analysisServers;

  @override
  Compiler get _compiler => _wrapped._compiler;

  @override
  ServerCache get _cache => _wrapped._cache;

  @override
  ServerContainer get _container => _wrapped._container;

  @override
  set _analysisServers(AnalysisServersWrapper __analysisServers) =>
      _wrapped._analysisServers = __analysisServers;

  @override
  set _compiler(Compiler __compiler) => _wrapped._compiler = __compiler;
}

final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent('  ');

class CommonServerImpl {
  final ServerContainer _container;
  final ServerCache _cache;

  Compiler _compiler;
  AnalysisServersWrapper _analysisServers;

  // Restarting and health status of the two Analysis Servers
  bool get analysisServersRunning => _analysisServers.running;
  bool get isRestarting => _analysisServers.isRestarting;
  bool get isHealthy => _analysisServers.isHealthy;

  CommonServerImpl(
    this._container,
    this._cache,
  ) {
    hierarchicalLoggingEnabled = true;
    log.level = Level.ALL;
  }

  Future<void> init() async {
    log.info('Beginning CommonServer init().');
    _analysisServers = AnalysisServersWrapper();
    _compiler = Compiler(SdkManager.sdk, SdkManager.flutterSdk);

    await _compiler.warmup();
    await _analysisServers.warmup();
  }

  Future<dynamic> shutdown() {
    return Future.wait(<Future<dynamic>>[
      _analysisServers.shutdown(),
      _compiler.dispose(),
      Future<dynamic>.sync(_cache.shutdown)
    ]).timeout(const Duration(minutes: 1));
  }

  Future<proto.AnalysisResults> analyze(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _analysisServers.analyze(request.source);
  }

  Future<proto.CompileResponse> compile(proto.CompileRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _compileDart2js(request.source,
        returnSourceMap: request.returnSourceMap ?? false);
  }

  Future<proto.CompileDDCResponse> compileDDC(proto.CompileDDCRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _compileDDC(request.source);
  }

  Future<proto.CompleteResponse> complete(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.complete(request.source, request.offset);
  }

  Future<proto.FixesResponse> fixes(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.getFixes(request.source, request.offset);
  }

  Future<proto.AssistsResponse> assists(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.getAssists(request.source, request.offset);
  }

  Future<proto.FormatResponse> format(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _analysisServers.format(request.source, request.offset ?? 0);
  }

  Future<proto.DocumentResponse> document(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return proto.DocumentResponse()
      ..info.addAll(
          await _analysisServers.dartdoc(request.source, request.offset) ??
              <String, String>{});
  }

  Future<proto.VersionResponse> version(proto.VersionRequest _) =>
      Future<proto.VersionResponse>.value(
        proto.VersionResponse()
          ..sdkVersion = SdkManager.sdk.version
          ..sdkVersionFull = SdkManager.sdk.versionFull
          ..runtimeVersion = vmVersion
          ..servicesVersion = servicesVersion
          ..appEngineVersion = _container.version
          ..flutterDartVersion = SdkManager.flutterSdk.version
          ..flutterDartVersionFull = SdkManager.flutterSdk.versionFull
          ..flutterVersion = SdkManager.flutterSdk.flutterVersion,
      );

  Future<proto.CompileResponse> _compileDart2js(
    String source, {
    bool returnSourceMap = false,
  }) async {
    try {
      final sourceHash = _hashSource(source);
      final memCacheKey = '%%COMPILE:v0'
          ':returnSourceMap:$returnSourceMap:source:$sourceHash';

      final result = await _checkCache(memCacheKey);
      if (result != null) {
        log.info('CACHE: Cache hit for compileDart2js');
        final resultObj = const JsonDecoder().convert(result);
        final response = proto.CompileResponse()
          ..result = resultObj['compiledJS'] as String;
        if (resultObj['sourceMap'] != null) {
          response.sourceMap = resultObj['sourceMap'] as String;
        }
        return response;
      }

      log.info('CACHE: MISS for compileDart2js');
      final watch = Stopwatch()..start();

      final results =
          await _compiler.compile(source, returnSourceMap: returnSourceMap);

      if (results.hasOutput) {
        final lineCount = source.split('\n').length;
        final outputSize = (results.compiledJS.length / 1024).ceil();
        final ms = watch.elapsedMilliseconds;
        log.info('PERF: Compiled $lineCount lines of Dart into '
            '${outputSize}kb of JavaScript in ${ms}ms using dart2js.');
        final sourceMap = returnSourceMap ? results.sourceMap : null;

        final cachedResult = const JsonEncoder().convert(<String, String>{
          'compiledJS': results.compiledJS,
          'sourceMap': sourceMap,
        });
        // Don't block on cache set.
        unawaited(_setCache(memCacheKey, cachedResult));
        final compileResponse = proto.CompileResponse();
        compileResponse.result = results.compiledJS;
        if (sourceMap != null) {
          compileResponse.sourceMap = sourceMap;
        }
        return compileResponse;
      } else {
        final problems = results.problems;
        final errors = problems.map(_printCompileProblem).join('\n');
        throw BadRequest(errors);
      }
    } catch (e, st) {
      if (e is! BadRequest) {
        log.severe('Error during compile (dart2js) on "$source"', e, st);
      }
      rethrow;
    }
  }

  Future<proto.CompileDDCResponse> _compileDDC(String source) async {
    try {
      final sourceHash = _hashSource(source);
      final memCacheKey = '%%COMPILE_DDC:v0:source:$sourceHash';

      final result = await _checkCache(memCacheKey);
      if (result != null) {
        log.info('CACHE: Cache hit for compileDDC');
        final resultObj = const JsonDecoder().convert(result);
        return proto.CompileDDCResponse()
          ..result = resultObj['compiledJS'] as String
          ..modulesBaseUrl = resultObj['modulesBaseUrl'] as String;
      }

      log.info('CACHE: MISS for compileDDC');
      final watch = Stopwatch()..start();

      final results = await _compiler.compileDDC(source);

      if (results.hasOutput) {
        final lineCount = source.split('\n').length;
        final outputSize = (results.compiledJS.length / 1024).ceil();
        final ms = watch.elapsedMilliseconds;
        log.info('PERF: Compiled $lineCount lines of Dart into '
            '${outputSize}kb of JavaScript in ${ms}ms using DDC.');

        final cachedResult = const JsonEncoder().convert(<String, String>{
          'compiledJS': results.compiledJS,
          'modulesBaseUrl': results.modulesBaseUrl,
        });
        // Don't block on cache set.
        unawaited(_setCache(memCacheKey, cachedResult));
        return proto.CompileDDCResponse()
          ..result = results.compiledJS
          ..modulesBaseUrl = results.modulesBaseUrl;
      } else {
        final problems = results.problems;
        final errors = problems.map(_printCompileProblem).join('\n');
        throw BadRequest(errors);
      }
    } catch (e, st) {
      if (e is! BadRequest) {
        log.severe('Error during compile (DDC) on "$source"', e, st);
      }
      rethrow;
    }
  }

  Future<String> _checkCache(String query) => _cache.get(query);

  Future<void> _setCache(String query, String result) =>
      _cache.set(query, result, expiration: _standardExpiration);
}

String _printCompileProblem(CompilationProblem problem) => problem.message;

String _hashSource(String str) {
  return sha1.convert(str.codeUnits).toString();
}
