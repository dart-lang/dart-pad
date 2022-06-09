// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_impl;

import 'dart:async';
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import '../version.dart';
import 'analysis_servers.dart';
import 'common.dart';
import 'compiler.dart';
import 'project.dart';
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
  final Sdk _sdk;

  late Compiler _compiler;
  late AnalysisServersWrapper _analysisServers;

  // Restarting and health status of the two Analysis Servers
  bool get isRestarting => _analysisServers.isRestarting;
  bool get isHealthy => _analysisServers.isHealthy;

  CommonServerImpl(
    this._container,
    this._cache,
    this._sdk,
  ) {
    hierarchicalLoggingEnabled = true;
    log.level = Level.ALL;
  }

  Future<void> init() async {
    log.info('Beginning CommonServer init().');
    _analysisServers = AnalysisServersWrapper(_sdk.dartSdkPath);
    _compiler = Compiler(_sdk);

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

    return _analysisServers.analyze(request.source, devMode: _sdk.devMode);
  }

  Future<proto.CompileResponse> compile(proto.CompileRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _compileDart2js({kMainDart: request.source},
        returnSourceMap: request.returnSourceMap);
  }

  Future<proto.CompileDDCResponse> compileDDC(proto.CompileDDCRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _compileDDC({kMainDart: request.source});
  }

  Future<proto.CompleteResponse> complete(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.complete(request.source, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.FixesResponse> fixes(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.getFixes(request.source, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.AssistsResponse> assists(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.getAssists(request.source, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.FormatResponse> format(proto.SourceRequest request) {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    return _analysisServers.format(request.source, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.DocumentResponse> document(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return proto.DocumentResponse()
      ..info.addAll(await _analysisServers
          .dartdoc(request.source, request.offset, devMode: _sdk.devMode));
  }

  // Beginning of multi files map entry points:
  Future<proto.AnalysisResults> analyzeFiles(proto.SourceFilesRequest request) {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }

    return _analysisServers.analyzeFiles(
        request.files, request.activeSourceName,
        devMode: _sdk.devMode);
  }

  Future<proto.CompileResponse> compileFiles(
      proto.CompileFilesRequest request) {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }

    return _compileDart2js(request.files,
        returnSourceMap: request.returnSourceMap);
  }

  Future<proto.CompileDDCResponse> compileFilesDDC(
      proto.CompileFilesDDCRequest request) {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }

    return _compileDDC(request.files);
  }

  Future<proto.CompleteResponse> completeFiles(
      proto.SourceFilesRequest request) {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }
    if (!request.hasActiveSourceName()) {
      throw BadRequest('Missing parameter: \'activeSourceName\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.completeFiles(
        request.files, request.activeSourceName, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.FixesResponse> fixesFiles(proto.SourceFilesRequest request) {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }
    if (!request.hasActiveSourceName()) {
      throw BadRequest('Missing parameter: \'activeSourceName\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.getFixesMulti(
        request.files, request.activeSourceName, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.AssistsResponse> assistsFiles(proto.SourceFilesRequest request) {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }
    if (!request.hasActiveSourceName()) {
      throw BadRequest('Missing parameter: \'activeSourceName\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return _analysisServers.getAssistsMulti(
        request.files, request.activeSourceName, request.offset,
        devMode: _sdk.devMode);
  }

  Future<proto.DocumentResponse> documentFiles(
      proto.SourceFilesRequest request) async {
    if (request.files.isEmpty) {
      throw BadRequest('Missing parameter: \'files\'');
    }
    if (!request.hasActiveSourceName()) {
      throw BadRequest('Missing parameter: \'activeSourceName\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    return proto.DocumentResponse()
      ..info.addAll(await _analysisServers.dartdocMulti(
          request.files, request.activeSourceName, request.offset,
          devMode: _sdk.devMode));
  }
  // End of files map entry points.

  Future<proto.VersionResponse> version(proto.VersionRequest _) {
    final packageVersions = getPackageVersions();
    final packageInfos = [
      for (var packageName in packageVersions.keys)
        proto.PackageInfo()
          ..name = packageName
          ..version = packageVersions[packageName]!
          ..supported = isSupportedPackage(packageName, devMode: _sdk.devMode),
    ];

    return Future.value(
      proto.VersionResponse()
        ..sdkVersion = _sdk.version
        ..sdkVersionFull = _sdk.versionFull
        ..runtimeVersion = vmVersion
        ..servicesVersion = servicesVersion
        ..appEngineVersion = _container.version
        ..flutterDartVersion = _sdk.version
        ..flutterDartVersionFull = _sdk.versionFull
        ..flutterVersion = _sdk.flutterVersion
        ..packageVersions.addAll(packageVersions)
        ..packageInfo.addAll(packageInfos),
    );
  }

  Future<proto.CompileResponse> _compileDart2js(
    Map<String, String> sources, {
    bool returnSourceMap = false,
  }) async {
    try {
      final sourceHash = _hashSources(sources);
      final memCacheKey = '%%COMPILE:v0'
          ':returnSourceMap:$returnSourceMap:source:$sourceHash';

      final result = await _checkCache(memCacheKey);
      if (result != null) {
        log.info('CACHE: Cache hit for compileDart2js');
        final resultObj = json.decode(result) as Map<String, dynamic>;
        final response = proto.CompileResponse()
          ..result = resultObj['compiledJS'] as String;
        if (resultObj['sourceMap'] != null) {
          response.sourceMap = resultObj['sourceMap'] as String;
        }
        return response;
      }

      log.info('CACHE: MISS for compileDart2js');
      final watch = Stopwatch()..start();

      final results = await _compiler.compileFiles(sources,
          returnSourceMap: returnSourceMap);

      if (results.hasOutput) {
        final lineCount = countLines(sources);
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
        log.severe('Error during compile (dart2js) on "$sources"', e, st);
      }
      rethrow;
    }
  }

  Future<proto.CompileDDCResponse> _compileDDC(
      Map<String, String> sources) async {
    try {
      final sourceHash = _hashSources(sources);
      final memCacheKey = '%%COMPILE_DDC:v0:source:$sourceHash';

      final result = await _checkCache(memCacheKey);
      if (result != null) {
        log.info('CACHE: Cache hit for compileDDC');
        final resultObj = json.decode(result) as Map<String, dynamic>;
        return proto.CompileDDCResponse()
          ..result = resultObj['compiledJS'] as String
          ..modulesBaseUrl = resultObj['modulesBaseUrl'] as String;
      }

      log.info('CACHE: MISS for compileDDC');
      final watch = Stopwatch()..start();

      final results = await _compiler.compileFilesDDC(sources);

      if (results.hasOutput) {
        final lineCount = countLines(sources);
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
        log.severe('Error during compile (DDC) on "$sources"', e, st);
      }
      rethrow;
    }
  }

  Future<String?> _checkCache(String query) => _cache.get(query);

  Future<void> _setCache(String query, String result) =>
      _cache.set(query, result, expiration: _standardExpiration);
}

String _printCompileProblem(CompilationProblem problem) => problem.message;

String _hashSources(Map<String, String> sources) {
  if (sources.length == 1) {
    // Special case optimized for single source file (and to work as before).
    return sha1.convert(sources.values.first.codeUnits).toString();
  } else {
    // Use chunk hashing method for >1 source files.
    final AccumulatorSink<Digest> hashoutput = AccumulatorSink<Digest>();
    final ByteConversionSink sha1Chunker =
        sha1.startChunkedConversion(hashoutput);
    sources.forEach((_, filecontents) {
      sha1Chunker.add(filecontents.codeUnits);
    });
    sha1Chunker.close();
    return hashoutput.events.single.toString();
  }
}
