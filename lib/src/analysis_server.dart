// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around an analysis server instance
library services.analysis_server;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'analysis_server_lib.dart';
import 'api_classes.dart' as api;
import 'common.dart';
import 'scheduler.dart';

final Logger _logger = new Logger('analysis_server');

/// Flag to determine whether we should dump the communication with the server
/// to stdout.
bool dumpServerMessages = false; // TODO: implement

final _WARMUP_SRC_HTML = "import 'dart:html'; main() { int b = 2;  b++;   b. }";
final _WARMUP_SRC = "main() { int b = 2;  b++;   b. }";
final _SERVER_PATH = "bin/snapshots/analysis_server.dart.snapshot";

// Use very long timeouts to ensure that the server has enough time to restart.
final Duration _ANALYSIS_SERVER_TIMEOUT = new Duration(seconds: 35);

class AnalysisServerWrapper {
  final String sdkPath;
  Future _init;
  Directory sourceDirectory;
  String mainPath;
  TaskScheduler serverScheduler;

  /// Instance to handle communication with the server.
  Server analysisServer;

  AnalysisServerWrapper(this.sdkPath) {
    _logger.info("AnalysisServerWrapper ctor");
    sourceDirectory = Directory.systemTemp.createTempSync('analysisServer');
    mainPath = _getPathFromName(kMainDart);
    serverScheduler = new TaskScheduler();
  }

  Future init() {
    if (_init == null) {
      _init = Server.createFromDefaults().then((Server server) async {
        analysisServer = server;
        analysisServer.server.setSubscriptions(['STATUS']);
        await analysisServer.analysis
            .setAnalysisRoots([sourceDirectory.path], []);
        await _sendAddOverlays({mainPath: _WARMUP_SRC});
        await _analysisComplete();
        return _unloadSources();
      });
    }

    return _init;
  }

  Future<api.CompleteResponse> complete(String src, int offset) async {
    return completeMulti(
        {kMainDart: src},
        new api.Location()
          ..sourceName = kMainDart
          ..offset = offset);
  }

  Future<api.CompleteResponse> completeMulti(
      Map<String, String> sources, api.Location location) async {
    CompletionResults results =
        await _completeImpl(sources, location.sourceName, location.offset);
    List<CompletionSuggestion> suggestions = results.results;

    // This hack filters out of scope completions. It needs removing when we
    // have categories of completions.
    suggestions = suggestions
        .where((CompletionSuggestion c) => c.relevance > 500)
        .toList();

    suggestions.sort((CompletionSuggestion x, CompletionSuggestion y) {
      if (x.relevance == y.relevance) {
        return x.completion.compareTo(y.completion);
      } else {
        return y.relevance.compareTo(x.relevance);
      }
    });

    return new api.CompleteResponse(
      results.replacementOffset,
      results.replacementLength,
      suggestions.map((CompletionSuggestion c) => c.originalMap).toList(),
    );
  }

  Future<api.FixesResponse> getFixes(String src, int offset) async {
    return getFixesMulti(
        {kMainDart: src}, new api.Location.from(kMainDart, offset));
  }

  Future<api.FixesResponse> getFixesMulti(
      Map<String, String> sources, api.Location location) async {
    FixesResult results =
        await _getFixesImpl(sources, location.sourceName, location.offset);
    List<api.ProblemAndFixes> responseFixes =
        results.fixes.map(_convertAnalysisErrorFix).toList();
    return new api.FixesResponse(responseFixes);
  }

  Future<api.FormatResponse> format(String src, int offset) async {
    return _formatImpl(src, offset).then((FormatResult editResult) {
      List<SourceEdit> edits = editResult.edits;

      edits.sort((e1, e2) => -1 * e1.offset.compareTo(e2.offset));

      for (SourceEdit edit in edits) {
        src = src.replaceRange(
            edit.offset, edit.offset + edit.length, edit.replacement);
      }

      return new api.FormatResponse(src, editResult.selectionOffset);
    }).catchError((error) {
      _logger.fine("format error: $error");
      return new api.FormatResponse(src, offset);
    });
  }

  /// Convert between the Analysis Server type and the API protocol types.
  static api.ProblemAndFixes _convertAnalysisErrorFix(
      AnalysisErrorFixes analysisFixes) {
    String problemMessage = analysisFixes.error.message;
    int problemOffset = analysisFixes.error.location.offset;
    int problemLength = analysisFixes.error.location.length;

    List<api.CandidateFix> possibleFixes = new List<api.CandidateFix>();

    for (var sourceChange in analysisFixes.fixes) {
      List<api.SourceEdit> edits = new List<api.SourceEdit>();

      // A fix that tries to modify other files is considered invalid.

      bool invalidFix = false;
      for (var sourceFileEdit in sourceChange.edits) {
        // TODO(lukechurch): replace this with a more reliable test based on the
        // psuedo file name in Analysis Server
        if (!sourceFileEdit.file.endsWith("/main.dart")) {
          invalidFix = true;
          break;
        }

        for (var sourceEdit in sourceFileEdit.edits) {
          edits.add(new api.SourceEdit.fromChanges(
              sourceEdit.offset, sourceEdit.length, sourceEdit.replacement));
        }
      }
      if (!invalidFix) {
        api.CandidateFix possibleFix =
            new api.CandidateFix.fromEdits(sourceChange.message, edits);
        possibleFixes.add(possibleFix);
      }
    }
    return new api.ProblemAndFixes.fromList(
        possibleFixes, problemMessage, problemOffset, problemLength);
  }

  /// Cleanly shutdown the Analysis Server.
  Future shutdown() {
    return analysisServer.server
        .shutdown()
        .timeout(new Duration(seconds: 1))
        .catchError((e) => null)
        .whenComplete(() => analysisServer.dispose());
  }

  /// Internal implementation of the completion mechanism.
  Future<CompletionResults> _completeImpl(
      Map<String, String> sources, String sourceName, int offset) async {
    if (serverScheduler.queueCount > 0) {
      _logger
          .info("completeImpl: Scheduler queue: ${serverScheduler.queueCount}");
    }

    return serverScheduler.schedule(new ClosureTask(() async {
      sources = _getOverlayMapWithPaths(sources);
      String path = _getPathFromName(sourceName);
      await _loadSources(sources);
      SuggestionsResult results =
          await analysisServer.completion.getSuggestions(path, offset);
      return _gatherCompletionResults(results.id)
          .then((CompletionResults ret) async {
        await _unloadSources();
        return ret;
      });
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<FixesResult> _getFixesImpl(
      Map<String, String> sources, String sourceName, int offset) async {
    sources = _getOverlayMapWithPaths(sources);
    String path = _getPathFromName(sourceName);

    if (serverScheduler.queueCount > 0) {
      _logger
          .fine("getFixesImpl: Scheduler queue: ${serverScheduler.queueCount}");
    }

    return serverScheduler.schedule(new ClosureTask(() async {
      await _loadSources(sources);
      await _analysisComplete();
      FixesResult fixes = await analysisServer.edit.getFixes(path, offset);
      await _unloadSources();
      return fixes;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<FormatResult> _formatImpl(String src, int offset) async {
    _logger.fine("FormatImpl: Scheduler queue: ${serverScheduler.queueCount}");

    return serverScheduler.schedule(new ClosureTask(() async {
      await _loadSources({mainPath: src});
      FormatResult result =
          await analysisServer.edit.format(mainPath, offset, 0);
      await _unloadSources();
      return result;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Map<String, String> _getOverlayMapWithPaths(Map<String, String> overlay) {
    var newOverlay = {};
    overlay.forEach(
        (k, v) => newOverlay.putIfAbsent(_getPathFromName(k), () => v));
    return newOverlay;
  }

  String _getPathFromName(String sourceName) =>
      "${sourceDirectory.path}${Platform.pathSeparator}$sourceName";

  /// Warm up the analysis server to be ready for use.
  Future warmup({bool useHtml = false}) =>
      complete(useHtml ? _WARMUP_SRC_HTML : _WARMUP_SRC, 10);

  Future _analysisComplete() {
    Completer completer = new Completer();
    StreamSubscription sub;
    sub = analysisServer.server.onStatus.listen((ServerStatus status) {
      if (status.analysis != null && !status.analysis.isAnalyzing) {
        // notify finished
        completer.complete(true);
        sub.cancel();
      }
    });
    return completer.future;
  }

  Set<String> _overlayPaths = new Set();

  Future _loadSources(Map<String, String> sources) async {
    if (_overlayPaths.isNotEmpty) {
      await _sendRemoveOverlays();
    }
    await _sendAddOverlays(sources);

    await analysisServer.analysis.setPriorityFiles(sources.keys.toList());
  }

  Future _unloadSources() {
    return Future.wait([
      _sendRemoveOverlays(),
      analysisServer.analysis.setPriorityFiles([]),
    ]);
  }

  Future _sendAddOverlays(Map<String, String> overlays) {
    Map<String, dynamic> params = {};
    for (String overlayPath in overlays.keys) {
      params[overlayPath] = new AddContentOverlay(overlays[overlayPath]);
    }

    _logger.fine("About to send analysis.updateContent");
    _logger.fine("  ${params.keys}");

    _overlayPaths.addAll(params.keys);

    return analysisServer.analysis.updateContent(params);
  }

  Future _sendRemoveOverlays() {
    _logger.fine("About to send analysis.updateContent remove overlays:");
    _logger.fine("  $_overlayPaths");

    Map<String, dynamic> params = {};
    for (String overlayPath in _overlayPaths) {
      params[overlayPath] = new RemoveContentOverlay();
    }
    _overlayPaths.clear();
    return analysisServer.analysis.updateContent(params);
  }

  Future<CompletionResults> _gatherCompletionResults(String id) {
    Completer<CompletionResults> completer = new Completer();
    StreamSubscription sub;

    sub =
        analysisServer.completion.onResults.listen((CompletionResults results) {
      if (results.id == id && results.isLast) {
        sub.cancel();
        completer.complete(results);
      }
    });

    return completer.future;
  }
}
