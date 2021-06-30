// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_impl;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';

import '../version.dart';
import 'analysis_servers.dart';
import 'common.dart';
import 'compiler.dart';
import 'protos/dart_services.pb.dart' as proto;
import 'pub.dart';
import 'sdk.dart';
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

class CommonServerImpl {
  final ServerContainer _container;
  final ServerCache _cache;
  final bool _nullSafety;

  late Compiler _compiler;
  late AnalysisServersWrapper _analysisServers;

  // Restarting and health status of the two Analysis Servers
  bool get isRestarting => _analysisServers.isRestarting;
  bool get isHealthy => _analysisServers.isHealthy;

  CommonServerImpl(
    this._container,
    this._cache,
    this._nullSafety,
  ) {
    hierarchicalLoggingEnabled = true;
    log.level = Level.ALL;
  }

  Future<void> init() async {
    log.info('Beginning CommonServer init().');
    _analysisServers = AnalysisServersWrapper(_nullSafety);
    _compiler = Compiler(Sdk.create(), _nullSafety);

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
        returnSourceMap: request.returnSourceMap);
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

    return _analysisServers.format(request.source, request.offset);
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
          await _analysisServers.dartdoc(request.source, request.offset));
  }

  Future<proto.VersionResponse> version(proto.VersionRequest _) {
    final sdk = Sdk.create();
    final packageVersions = getPackageVersions(nullSafe: _nullSafety);

    return Future.value(
      proto.VersionResponse()
        ..sdkVersion = sdk.version
        ..sdkVersionFull = sdk.versionFull
        ..runtimeVersion = vmVersion
        ..servicesVersion = servicesVersion
        ..appEngineVersion = _container.version
        ..flutterDartVersion = sdk.version
        ..flutterDartVersionFull = sdk.versionFull
        ..flutterVersion = sdk.flutterVersion
        ..packageVersions.addAll(packageVersions),
    );
  }

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
        final outputSize = (results.compiledJS?.length ?? 0 / 1024).ceil();
        final ms = watch.elapsedMilliseconds;
        log.info('PERF: Compiled $lineCount lines of Dart into '
            '${outputSize}kb of JavaScript in ${ms}ms using dart2js.');
        final sourceMap = returnSourceMap ? results.sourceMap : null;

        final cachedResult = const JsonEncoder().convert(<String, String?>{
          'compiledJS': results.compiledJS,
          'sourceMap': sourceMap,
        });
        // Don't block on cache set.
        unawaited(_setCache(memCacheKey, cachedResult));
        final compileResponse = proto.CompileResponse();
        compileResponse.result = results.compiledJS ?? '';
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
        final outputSize = (results.compiledJS?.length ?? 0 / 1024).ceil();
        final ms = watch.elapsedMilliseconds;
        log.info('PERF: Compiled $lineCount lines of Dart into '
            '${outputSize}kb of JavaScript in ${ms}ms using DDC.');

        final cachedResult = const JsonEncoder().convert(<String, String>{
          'compiledJS': results.compiledJS ?? '',
          'modulesBaseUrl': results.modulesBaseUrl ?? '',
        });
        // Don't block on cache set.
        unawaited(_setCache(memCacheKey, cachedResult));
        return proto.CompileDDCResponse()
          ..result = results.compiledJS ?? ''
          ..modulesBaseUrl = results.modulesBaseUrl ?? '';
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

  Future<String?> _checkCache(String query) => _cache.get(query);

  Future<void> _setCache(String query, String result) =>
      _cache.set(query, result, expiration: _standardExpiration);
}

String _printCompileProblem(CompilationProblem problem) => problem.message;

String _hashSource(String str) {
  return sha1.convert(str.codeUnits).toString();
}
