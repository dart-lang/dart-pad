// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around an analysis server instance
library services.analysis_server;

import 'dart:async';
import 'dart:io';

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'api_classes.dart' as api;
import 'common.dart';
import 'pub.dart';
import 'scheduler.dart';

final Logger _logger = new Logger('analysis_server');

/// Flag to determine whether we should dump the communication with the server
/// to stdout.
bool dumpServerMessages = false;

final _WARMUP_SRC_HTML = "import 'dart:html'; main() { int b = 2;  b++;   b. }";
final _WARMUP_SRC = "main() { int b = 2;  b++;   b. }";

// Use very long timeouts to ensure that the server has enough time to restart.
final Duration _ANALYSIS_SERVER_TIMEOUT = new Duration(seconds: 35);

class AnalysisServerWrapper {
  final String sdkPath;

  final bool previewDart2;
  Future _init;
  Directory sourceDirectory;
  String mainPath;
  TaskScheduler serverScheduler;

  /// Instance to handle communication with the server.
  AnalysisServer analysisServer;

  AnalysisServerWrapper(this.sdkPath, {this.previewDart2: false}) {
    if (previewDart2 == true) ;
    _logger.info('AnalysisServerWrapper ctor, previewDart2: $previewDart2');
    sourceDirectory = Directory.systemTemp.createTempSync('analysisServer');
    mainPath = _getPathFromName(kMainDart);

    serverScheduler = new TaskScheduler();

    // Write an analysis_options.yaml file with strong mode enabled.
    // TODO(jcollins-g): this is only required for Travis.  Find out why, then
    // remove this hack.
    File optionsFile = new File(_getPathFromName('analysis_options.yaml'));
    optionsFile.writeAsStringSync(
        'analyzer:\n  strong-mode: true\n  enablePreviewDart2: $previewDart2\n');
  }

  Future init() {
    if (_init == null) {
      void onRead(String str) {
        if (dumpServerMessages) _logger.info('<-- $str');
      }

      void onWrite(String str) {
        if (dumpServerMessages) _logger.info('--> $str');
      }

      List<String> serverArgs = <String>[
        '--${previewDart2 ? '' : 'no-'}preview-dart-2',
        '--dartpad',
        '--client-id=DartPad',
        '--client-version=${_sdkVersion}'
      ];
      _logger.info("About to start with server with args: $serverArgs");

      _init = AnalysisServer
          .create(
        onRead: onRead,
        onWrite: onWrite,
        sdkPath: sdkPath,
        serverArgs: serverArgs,
      )
          .then((AnalysisServer server) async {
        analysisServer = server;
        analysisServer.server.onError.listen((ServerError error) {
          _logger.severe('server error${error.isFatal ? ' (fatal)' : ''}',
              error.message, new StackTrace.fromString(error.stackTrace));
        });
        await analysisServer.server.onConnected.first;
        await analysisServer.server.setSubscriptions(['STATUS']);

        listenForCompletions();
        listenForAnalysisComplete();
        listenForErrors();

        Completer analysisComplete = getAnalysisCompleteCompleter();
        await analysisServer.analysis
            .setAnalysisRoots([sourceDirectory.path], []);
        await _sendAddOverlays({mainPath: _WARMUP_SRC});
        await analysisComplete.future;
        await _sendRemoveOverlays();
      });
    }

    return _init;
  }

  String get _sdkVersion {
    return new File(path.join(sdkPath, 'version')).readAsStringSync().trim();
  }

  Future<int> get onExit {
    // Return when the analysis server exits. We introduce a delay so that when
    // we terminate the analysis server we can exit normally.
    return analysisServer.processCompleter.future.then((int code) {
      return new Future.delayed(new Duration(seconds: 1), () {
        return code;
      });
    });
  }

  Future<api.CompleteResponse> complete(String src, int offset) {
    return completeMulti(
      {kMainDart: src},
      new api.Location.from(kMainDart, offset),
    );
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
      suggestions.map((CompletionSuggestion c) => c.toMap()).toList(),
    );
  }

  Future<api.FixesResponse> getFixes(String src, int offset) {
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

  Future<api.FormatResponse> format(String src, int offset) {
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

  Future<Map<String, String>> dartdoc(String source, int offset) {
    _logger.fine("dartdoc: Scheduler queue: ${serverScheduler.queueCount}");

    return serverScheduler.schedule(new ClosureTask(() async {
      Completer analysisCompleter = getAnalysisCompleteCompleter();
      await _loadSources({mainPath: source});
      await analysisCompleter.future;

      HoverResult result =
          await analysisServer.analysis.getHover(mainPath, offset);
      await _unloadSources();

      if (result.hovers.isEmpty) {
        return null;
      }

      HoverInformation info = result.hovers.first;
      Map<String, String> m = {};

      m['description'] = info.elementDescription;
      m['kind'] = info.elementKind;
      m['dartdoc'] = info.dartdoc;

      m['enclosingClassName'] = info.containingClassDescription;
      m['libraryName'] = info.containingLibraryName;

      m['deprecated'] = info.parameter;
      if (info.isDeprecated != null) m['deprecated'] = '${info.isDeprecated}';

      m['staticType'] = info.staticType;
      m['propagatedType'] = info.propagatedType;

      for (String key in m.keys.toList()) {
        if (m[key] == null) m.remove(key);
      }

      return m;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<api.AnalysisResults> analyze(String source) {
    return analyzeMulti({kMainDart: source});
  }

  Future<api.AnalysisResults> analyzeMulti(Map<String, String> sources) {
    _logger
        .fine("analyzeMulti: Scheduler queue: ${serverScheduler.queueCount}");

    return serverScheduler.schedule(new ClosureTask(() async {
      clearErrors();

      Completer analysisCompleter = getAnalysisCompleteCompleter();
      sources = _getOverlayMapWithPaths(sources);
      await _loadSources(sources);
      await analysisCompleter.future;

      // Calculate the issues.
      List<api.AnalysisIssue> issues = getErrors().map((AnalysisError error) {
        return new api.AnalysisIssue.fromIssue(
          error.severity.toLowerCase(),
          error.location.startLine,
          error.message,
          charStart: error.location.offset,
          charLength: error.location.length,
          sourceName: path.basename(error.location.file),
          hasFixes: error.hasFix,
        );
      }).toList();

      issues.sort();

      // Calculate the imports.
      Set<String> packageImports = new Set();
      for (String source in sources.values) {
        packageImports.addAll(
            filterSafePackagesFromImports(getAllUnsafeImportsFor(source)));
      }

      return new api.AnalysisResults(
        issues,
        packageImports.toList(),
      );
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
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
      await _loadSources(sources);
      SuggestionsResult id = await analysisServer.completion.getSuggestions(
        _getPathFromName(sourceName),
        offset,
      );
      CompletionResults results = await getCompletionResults(id.id);
      await _unloadSources();
      return results;
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
      Completer analysisCompleter = getAnalysisCompleteCompleter();
      await _loadSources(sources);
      await analysisCompleter.future;
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
    Map<String, String> newOverlay = {};
    for (String key in overlay.keys) {
      newOverlay[_getPathFromName(key)] = overlay[key];
    }
    return newOverlay;
  }

  String _getPathFromName(String sourceName) =>
      path.join(sourceDirectory.path, sourceName);

  /// Warm up the analysis server to be ready for use.
  Future warmup({bool useHtml = false}) =>
      complete(useHtml ? _WARMUP_SRC_HTML : _WARMUP_SRC, 10);

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
    Map<String, ContentOverlayType> params = {};
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

    Map<String, ContentOverlayType> params = {};
    for (String overlayPath in _overlayPaths) {
      params[overlayPath] = new RemoveContentOverlay();
    }
    _overlayPaths.clear();
    return analysisServer.analysis.updateContent(params);
  }

  Map<String, Completer<CompletionResults>> _completionCompleters = {};

  void listenForCompletions() {
    analysisServer.completion.onResults.listen((CompletionResults result) {
      if (result.isLast) {
        Completer<CompletionResults> completer =
            _completionCompleters.remove(result.id);
        if (completer != null) {
          completer.complete(result);
        }
      }
    });
  }

  Future<CompletionResults> getCompletionResults(String id) {
    _completionCompleters[id] = new Completer<CompletionResults>();
    return _completionCompleters[id].future;
  }

  List<Completer> _analysisCompleters = [];

  void listenForAnalysisComplete() {
    analysisServer.server.onStatus.listen((ServerStatus status) {
      if (status.analysis == null) return;

      if (!status.analysis.isAnalyzing) {
        for (Completer completer in _analysisCompleters) {
          completer.complete();
        }

        _analysisCompleters.clear();
      }
    });
  }

  Completer getAnalysisCompleteCompleter() {
    Completer completer = new Completer();
    _analysisCompleters.add(completer);
    return completer;
  }

  Map<String, List<AnalysisError>> _errors = {};

  void listenForErrors() {
    analysisServer.analysis.onErrors.listen((AnalysisErrors result) {
      if (result.errors.isEmpty) {
        _errors.remove(result.file);
      } else {
        _errors[result.file] = result.errors;
      }
    });
  }

  void clearErrors() => _errors.clear();

  List<AnalysisError> getErrors() {
    List<AnalysisError> errors = [];
    for (List<AnalysisError> e in _errors.values) {
      errors.addAll(e);
    }
    return errors;
  }
}
