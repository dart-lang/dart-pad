// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around an analysis server instance.
library services.analysis_servers;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';

import 'analysis_server.dart';
import 'common_server_impl.dart' show BadRequest;
import 'flutter_web.dart';
import 'protos/dart_services.pb.dart' as proto;
import 'pub.dart';
import 'sdk_manager.dart';

final Logger _logger = Logger('analysis_servers');

class AnalysisServersWrapper {
  AnalysisServersWrapper();

  FlutterWebManager _flutterWebManager;
  DartAnalysisServerWrapper _dartAnalysisServer;
  FlutterAnalysisServerWrapper _flutterAnalysisServer;

  bool get running =>
      _dartAnalysisServer.analysisServer != null &&
      _flutterAnalysisServer.analysisServer != null;

  // If non-null, this value indicates that the server is starting/restarting
  // and holds the time at which that process began. If null, the server is
  // ready to handle requests.
  DateTime _restartingSince = DateTime.now();

  bool get isRestarting => (_restartingSince != null);

  // If the server has been trying and failing to restart for more than a half
  // hour, something is seriously wrong.
  bool get isHealthy => (_restartingSince == null ||
      DateTime.now().difference(_restartingSince).inMinutes < 30);

  Future<void> warmup() async {
    _logger.info('Beginning AnalysisServersWrapper init().');
    _dartAnalysisServer = DartAnalysisServerWrapper();
    _flutterWebManager = FlutterWebManager(SdkManager.sdk);
    _flutterAnalysisServer = FlutterAnalysisServerWrapper(_flutterWebManager);

    await _dartAnalysisServer.init();
    _logger.info('Dart analysis server initialized.');

    await _flutterAnalysisServer.init();
    _logger.info('Flutter analysis server initialized.');

    unawaited(_dartAnalysisServer.onExit.then((int code) {
      _logger.severe('dartAnalysisServer exited, code: $code');
      if (code != 0) {
        exit(code);
      }
    }));

    unawaited(_flutterAnalysisServer.onExit.then((int code) {
      _logger.severe('flutterAnalysisServer exited, code: $code');
      if (code != 0) {
        exit(code);
      }
    }));

    _restartingSince = null;

    return Future.wait(<Future<dynamic>>[
      _flutterAnalysisServer.warmup(),
      _dartAnalysisServer.warmup(),
    ]);
  }

  Future<void> _restart() async {
    _logger.warning('Restarting');
    await shutdown();
    _logger.info('shutdown');

    await warmup();
    _logger.warning('Restart complete');
  }

  Future<dynamic> shutdown() {
    _restartingSince = DateTime.now();

    return Future.wait(<Future<dynamic>>[
      _flutterAnalysisServer.shutdown(),
      _dartAnalysisServer.shutdown(),
    ]);
  }

  AnalysisServerWrapper _getCorrectAnalysisServer(String source) {
    final imports = getAllImportsFor(source);
    return _flutterWebManager.usesFlutterWeb(imports)
        ? _flutterAnalysisServer
        : _dartAnalysisServer;
  }

  Future<proto.AnalysisResults> analyze(String source) => _perfLogAndRestart(
      source,
      () => _getCorrectAnalysisServer(source).analyze(source),
      'analysis',
      'Error during analyze on "$source"');

  Future<proto.CompleteResponse> complete(String source, int offset) =>
      _perfLogAndRestart(
          source,
          () => _getCorrectAnalysisServer(source).complete(source, offset),
          'completions',
          'Error during complete on "$source" at $offset');

  Future<proto.FixesResponse> getFixes(String source, int offset) =>
      _perfLogAndRestart(
          source,
          () => _getCorrectAnalysisServer(source).getFixes(source, offset),
          'fixes',
          'Error during fixes on "$source" at $offset');

  Future<proto.AssistsResponse> getAssists(String source, int offset) =>
      _perfLogAndRestart(
          source,
          () => _getCorrectAnalysisServer(source).getAssists(source, offset),
          'assists',
          'Error during assists on "$source" at $offset');

  Future<proto.FormatResponse> format(String source, int offset) =>
      _perfLogAndRestart(
          source,
          () => _getCorrectAnalysisServer(source).format(source, offset),
          'format',
          'Error during format on "$source" at $offset');

  Future<Map<String, String>> dartdoc(String source, int offset) =>
      _perfLogAndRestart(
          source,
          () => _getCorrectAnalysisServer(source).dartdoc(source, offset),
          'dartdoc',
          'Error during dartdoc on "$source" at $offset');

  Future<T> _perfLogAndRestart<T>(String source, Future<T> Function() body,
      String action, String errorDescription) async {
    await _checkPackageReferences(source);
    try {
      final watch = Stopwatch()..start();
      final response = await body();
      _logger.info('PERF: Computed $action in ${watch.elapsedMilliseconds}ms.');
      return response;
    } catch (e, st) {
      _logger.severe(errorDescription, e, st);
      await _restart();
      rethrow;
    }
  }

  /// Check that the set of packages referenced is valid.
  Future<void> _checkPackageReferences(String source) async {
    final imports = getAllImportsFor(source);

    if (_flutterWebManager.hasUnsupportedImport(imports)) {
      throw BadRequest(
          'Unsupported input: ${_flutterWebManager.getUnsupportedImport(imports)}');
    }
  }
}
