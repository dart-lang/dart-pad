// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around an analysis server instance.
library;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:logging/logging.dart';

import 'analysis_server.dart';
import 'common.dart';
import 'common_server_impl.dart' show BadRequest;
import 'project.dart' as project;
import 'protos/dart_services.pb.dart' as proto;
import 'pub.dart';

final Logger _logger = Logger('analysis_servers');

class AnalyzerWrapper {
  final String _dartSdkPath;

  AnalyzerWrapper(this._dartSdkPath);

  late DartAnalysisServerWrapper _dartAnalysisServer;

  // If non-null, this value indicates that the server is starting/restarting
  // and holds the time at which that process began. If null, the server is
  // ready to handle requests.
  DateTime? _restartingSince = DateTime.now();

  bool get isRestarting => _restartingSince != null;

  // If the server has been trying and failing to restart for more than a half
  // hour, something is seriously wrong.
  bool get isHealthy =>
      _restartingSince == null ||
      DateTime.now().difference(_restartingSince!).inMinutes < 30;

  Future<void> init() async {
    _logger.fine('Beginning AnalysisServersWrapper init().');
    _dartAnalysisServer = DartAnalysisServerWrapper(dartSdkPath: _dartSdkPath);
    await _dartAnalysisServer.init();
    _logger.info('Analysis server initialized.');

    unawaited(_dartAnalysisServer.onExit.then((int code) {
      _logger.severe('analysis server exited, code: $code');
      if (code != 0) {
        exit(code);
      }
    }));

    _restartingSince = null;
  }

  Future<void> _restart() async {
    _logger.warning('Restarting');
    await shutdown();
    _logger.info('shutdown');

    await init();
    _logger.warning('Restart complete');
  }

  Future<dynamic> shutdown() {
    _restartingSince = DateTime.now();

    return _dartAnalysisServer.shutdown();
  }

  Future<proto.AnalysisResults> analyze(String source,
          {required bool devMode}) =>
      analyzeFiles({kMainDart: source}, kMainDart, devMode: devMode);

  Future<proto.AnalysisResults> analyzeFiles(
          Map<String, String> sources, String activeSourceName,
          {required bool devMode}) =>
      _perfLogAndRestart(
          sources,
          activeSourceName,
          0,
          (List<ImportDirective> imports, Location location) =>
              _dartAnalysisServer.analyzeFiles(sources, imports: imports),
          'analysis',
          'Error during analyze on "${sources[activeSourceName]}"',
          devMode: devMode);

  Future<proto.CompleteResponse> complete(String source, int offset,
          {required bool devMode}) =>
      completeFiles({kMainDart: source}, kMainDart, offset, devMode: devMode);

  Future<proto.CompleteResponse> completeFiles(
          Map<String, String> sources, String activeSourceName, int offset,
          {required bool devMode}) =>
      _perfLogAndRestart(
          sources,
          activeSourceName,
          offset,
          (List<ImportDirective> imports, Location location) =>
              _dartAnalysisServer.completeFiles(sources, location),
          'completions',
          'Error during complete on "${sources[activeSourceName]}" at $offset',
          devMode: devMode);

  Future<proto.FixesResponse> getFixes(String source, int offset,
          {required bool devMode}) =>
      getFixesMulti({kMainDart: source}, kMainDart, offset, devMode: devMode);

  Future<proto.FixesResponse> getFixesMulti(
          Map<String, String> sources, String activeSourceName, int offset,
          {required bool devMode}) =>
      _perfLogAndRestart(
          sources,
          activeSourceName,
          offset,
          (List<ImportDirective> imports, Location location) =>
              _dartAnalysisServer.getFixesMulti(sources, location),
          'fixes',
          'Error during fixes on "${sources[activeSourceName]}" at $offset',
          devMode: devMode);

  Future<proto.AssistsResponse> getAssists(String source, int offset,
          {required bool devMode}) =>
      getAssistsMulti({kMainDart: source}, kMainDart, offset, devMode: devMode);

  Future<proto.AssistsResponse> getAssistsMulti(
          Map<String, String> sources, String activeSourceName, int offset,
          {required bool devMode}) =>
      _perfLogAndRestart(
          sources,
          activeSourceName,
          offset,
          (List<ImportDirective> imports, Location location) =>
              _dartAnalysisServer.getAssistsMulti(sources, location),
          'assists',
          'Error during assists on "${sources[activeSourceName]}" at $offset',
          devMode: devMode);

  Future<proto.FormatResponse> format(String source, int offset,
      {required bool devMode}) {
    return _perfLogAndRestart(
        {kMainDart: source},
        kMainDart,
        offset,
        (List<ImportDirective> imports, Location _) =>
            _dartAnalysisServer.format(source, offset),
        'format',
        'Error during format at $offset',
        devMode: devMode);
  }

  Future<Map<String, String>> dartdoc(String source, int offset,
          {required bool devMode}) =>
      dartdocMulti({kMainDart: source}, kMainDart, offset, devMode: devMode);

  Future<Map<String, String>> dartdocMulti(
          Map<String, String> sources, String activeSourceName, int offset,
          {required bool devMode}) =>
      _perfLogAndRestart(
          sources,
          activeSourceName,
          offset,
          (List<ImportDirective> imports, Location location) =>
              _dartAnalysisServer.dartdocMulti(sources, location),
          'dartdoc',
          'Error during dartdoc on "${sources[activeSourceName]}" at $offset',
          devMode: devMode);

  Future<T> _perfLogAndRestart<T>(
    Map<String, String> sources,
    String activeSourceName,
    int offset,
    Future<T> Function(List<ImportDirective>, Location) body,
    String action,
    String errorDescription, {
    required bool devMode,
  }) async {
    activeSourceName = sanitizeAndCheckFilenames(sources, activeSourceName);
    final imports = getAllImportsForFiles(sources);
    final location = Location(activeSourceName, offset);
    await _checkPackageReferences(sources, imports, devMode: devMode);
    try {
      final watch = Stopwatch()..start();
      final response = await body(imports, location);
      _logger.fine('PERF: Computed $action in ${watch.elapsedMilliseconds}ms.');
      return response;
    } catch (e, st) {
      _logger.severe(errorDescription, e, st);
      await _restart();
      rethrow;
    }
  }

  /// Check that the set of packages referenced is valid.
  Future<void> _checkPackageReferences(
      Map<String, String> sources, List<ImportDirective> imports,
      {required bool devMode}) async {
    final unsupportedImports = project.getUnsupportedImports(imports,
        sourcesFileList: sources.keys.toList(), devMode: devMode);

    if (unsupportedImports.isNotEmpty) {
      // TODO(srawlins): Do the work so that each unsupported input is its own
      // error, with a proper SourceSpan.
      final unsupportedUris =
          unsupportedImports.map((import) => import.uri.stringValue);
      throw BadRequest('Unsupported import(s): $unsupportedUris');
    }
  }
}
