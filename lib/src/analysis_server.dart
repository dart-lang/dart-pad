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
import 'flutter_web.dart';
import 'pub.dart';
import 'scheduler.dart';

final Logger _logger = Logger('analysis_server');

/// Flag to determine whether we should dump the communication with the server
/// to stdout.
bool dumpServerMessages = false;

final String _WARMUP_SRC_HTML =
    "import 'dart:html'; main() { int b = 2;  b++;   b. }";
final String _WARMUP_SRC = 'main() { int b = 2;  b++;   b. }';

// Use very long timeouts to ensure that the server has enough time to restart.
final Duration _ANALYSIS_SERVER_TIMEOUT = Duration(seconds: 35);

class AnalysisServerWrapper {
  final String sdkPath;
  final FlutterWebManager flutterWebManager;

  Future<AnalysisServer> _init;
  String mainPath;
  TaskScheduler serverScheduler;

  /// Instance to handle communication with the server.
  AnalysisServer analysisServer;

  AnalysisServerWrapper(this.sdkPath, this.flutterWebManager) {
    _logger.info('AnalysisServerWrapper ctor');
    mainPath = _getPathFromName(kMainDart);

    serverScheduler = TaskScheduler();
  }

  String get _sourceDirPath => flutterWebManager.projectDirectory.path;

  Future<AnalysisServer> init() {
    if (_init == null) {
      void onRead(String str) {
        if (dumpServerMessages) _logger.info('<-- $str');
      }

      void onWrite(String str) {
        if (dumpServerMessages) _logger.info('--> $str');
      }

      final serverArgs = <String>[
        '--dartpad',
        '--client-id=DartPad',
        '--client-version=$_sdkVersion'
      ];
      _logger.info(
          'About to start with server with SDK path `$sdkPath` and args: $serverArgs');

      _init = AnalysisServer.create(
        onRead: onRead,
        onWrite: onWrite,
        sdkPath: sdkPath,
        serverArgs: serverArgs,
      ).then((AnalysisServer server) async {
        analysisServer = server;
        analysisServer.server.onError.listen((ServerError error) {
          _logger.severe('server error${error.isFatal ? ' (fatal)' : ''}',
              error.message, StackTrace.fromString(error.stackTrace));
        });
        await analysisServer.server.onConnected.first;
        await analysisServer.server.setSubscriptions(<String>['STATUS']);

        listenForCompletions();
        listenForAnalysisComplete();
        listenForErrors();

        final analysisComplete = getAnalysisCompleteCompleter();
        await analysisServer.analysis
            .setAnalysisRoots(<String>[_sourceDirPath], <String>[]);
        await _sendAddOverlays(<String, String>{mainPath: _WARMUP_SRC});
        await analysisComplete.future;
        await _sendRemoveOverlays();

        return analysisServer;
      }).catchError((err, st) {
        _logger.severe('Error starting analysis server ($sdkPath): $err.\n$st');
      });
    }

    return _init;
  }

  String get _sdkVersion {
    return File(path.join(sdkPath, 'version')).readAsStringSync().trim();
  }

  Future<int> get onExit {
    // Return when the analysis server exits. We introduce a delay so that when
    // we terminate the analysis server we can exit normally.
    return analysisServer.processCompleter.future.then((int code) {
      return Future<int>.delayed(Duration(seconds: 1), () {
        return code;
      });
    });
  }

  Future<api.CompleteResponse> complete(String src, int offset) async {
    final sources = <String, String>{kMainDart: src};
    final location = api.Location.from(kMainDart, offset);

    final results =
        await _completeImpl(sources, location.sourceName, location.offset);
    var suggestions = results.results;

    final source = sources[location.sourceName];
    final prefix = source.substring(results.replacementOffset, location.offset);
    suggestions = suggestions
        .where(
            (s) => s.completion.toLowerCase().startsWith(prefix.toLowerCase()))
        // This hack filters out of scope completions. It needs removing when we
        // have categories of completions.
        // TODO(devoncarew): Remove this filter code.
        .where((CompletionSuggestion c) => c.relevance > 500)
        .toList();

    suggestions.sort((CompletionSuggestion x, CompletionSuggestion y) {
      if (x.relevance == y.relevance) {
        return x.completion.compareTo(y.completion);
      } else {
        return y.relevance.compareTo(x.relevance);
      }
    });

    return api.CompleteResponse(
      results.replacementOffset,
      results.replacementLength,
      suggestions.map((CompletionSuggestion c) => c.toMap()).toList(),
    );
  }

  Future<api.FixesResponse> getFixes(String src, int offset) {
    return getFixesMulti(
      <String, String>{kMainDart: src},
      api.Location.from(kMainDart, offset),
    );
  }

  Future<api.FixesResponse> getFixesMulti(
      Map<String, String> sources, api.Location location) async {
    final results =
        await _getFixesImpl(sources, location.sourceName, location.offset);
    final responseFixes = results.fixes.map(_convertAnalysisErrorFix).toList();
    return api.FixesResponse(responseFixes);
  }

  Future<api.AssistsResponse> getAssists(String src, int offset) async {
    final sources = {kMainDart: src};
    final sourceName = api.Location.from(kMainDart, offset).sourceName;
    final results = await _getAssistsImpl(sources, sourceName, offset);
    final fixes = _convertSourceChangesToCandidateFixes(results.assists);
    return api.AssistsResponse(fixes);
  }

  Future<api.FormatResponse> format(String src, int offset) {
    return _formatImpl(src, offset).then((FormatResult editResult) {
      final edits = editResult.edits;

      edits.sort((SourceEdit e1, SourceEdit e2) =>
          -1 * e1.offset.compareTo(e2.offset));

      for (final edit in edits) {
        src = src.replaceRange(
            edit.offset, edit.offset + edit.length, edit.replacement);
      }

      return api.FormatResponse(src, editResult.selectionOffset);
    }).catchError((dynamic error) {
      _logger.fine('format error: $error');
      return api.FormatResponse(src, offset);
    });
  }

  Future<Map<String, String>> dartdoc(String source, int offset) {
    _logger.fine('dartdoc: Scheduler queue: ${serverScheduler.queueCount}');

    return serverScheduler.schedule(ClosureTask<Map<String, String>>(() async {
      final analysisCompleter = getAnalysisCompleteCompleter();
      await _loadSources(<String, String>{mainPath: source});
      await analysisCompleter.future;

      final result = await analysisServer.analysis.getHover(mainPath, offset);
      await _unloadSources();

      if (result.hovers.isEmpty) {
        return null;
      }

      final info = result.hovers.first;
      final m = <String, String>{};

      m['description'] = info.elementDescription;
      m['kind'] = info.elementKind;
      m['dartdoc'] = info.dartdoc;

      m['enclosingClassName'] = info.containingClassDescription;
      m['libraryName'] = info.containingLibraryName;

      m['deprecated'] = info.parameter;
      if (info.isDeprecated != null) m['deprecated'] = '${info.isDeprecated}';

      m['staticType'] = info.staticType;
      m['propagatedType'] = info.propagatedType;

      for (final key in m.keys.toList()) {
        if (m[key] == null) m.remove(key);
      }

      return m;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<api.AnalysisResults> analyze(String source) {
    var sources = <String, String>{kMainDart: source};

    _logger
        .fine('analyzeMulti: Scheduler queue: ${serverScheduler.queueCount}');

    return serverScheduler.schedule(ClosureTask<api.AnalysisResults>(() async {
      clearErrors();

      final analysisCompleter = getAnalysisCompleteCompleter();
      sources = _getOverlayMapWithPaths(sources);
      await _loadSources(sources);
      await analysisCompleter.future;

      // Calculate the issues.
      final issues = getErrors().map((AnalysisError error) {
        return api.AnalysisIssue.fromIssue(
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
      final packageImports = <String>{};
      for (final source in sources.values) {
        packageImports
            .addAll(filterSafePackagesFromImports(getAllImportsFor(source)));
      }

      return api.AnalysisResults(
        issues,
        packageImports.toList(),
      );
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<AssistsResult> _getAssistsImpl(
      Map<String, String> sources, String sourceName, int offset) {
    sources = _getOverlayMapWithPaths(sources);
    final path = _getPathFromName(sourceName);

    if (serverScheduler.queueCount > 0) {
      _logger.fine(
          'getRefactoringsImpl: Scheduler queue: ${serverScheduler.queueCount}');
    }

    return serverScheduler.schedule(ClosureTask<AssistsResult>(() async {
      final analysisCompleter = getAnalysisCompleteCompleter();
      await _loadSources(sources);
      await analysisCompleter.future;
      final length = 1;
      final assists =
          await analysisServer.edit.getAssists(path, offset, length);
      await _unloadSources();
      return assists;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  /// Convert between the Analysis Server type and the API protocol types.
  static api.ProblemAndFixes _convertAnalysisErrorFix(
      AnalysisErrorFixes analysisFixes) {
    final problemMessage = analysisFixes.error.message;
    final problemOffset = analysisFixes.error.location.offset;
    final problemLength = analysisFixes.error.location.length;

    final possibleFixes = <api.CandidateFix>[];

    for (final sourceChange in analysisFixes.fixes) {
      final edits = <api.SourceEdit>[];

      // A fix that tries to modify other files is considered invalid.

      var invalidFix = false;
      for (final sourceFileEdit in sourceChange.edits) {
        // TODO(lukechurch): replace this with a more reliable test based on the
        // psuedo file name in Analysis Server
        if (!sourceFileEdit.file.endsWith('/main.dart')) {
          invalidFix = true;
          break;
        }

        for (final sourceEdit in sourceFileEdit.edits) {
          edits.add(api.SourceEdit.fromChanges(
              sourceEdit.offset, sourceEdit.length, sourceEdit.replacement));
        }
      }
      if (!invalidFix) {
        final possibleFix =
            api.CandidateFix.fromEdits(sourceChange.message, edits);
        possibleFixes.add(possibleFix);
      }
    }
    return api.ProblemAndFixes.fromList(
        possibleFixes, problemMessage, problemOffset, problemLength);
  }

  static List<api.CandidateFix> _convertSourceChangesToCandidateFixes(
      List<SourceChange> sourceChanges) {
    final assists = <api.CandidateFix>[];

    for (final sourceChange in sourceChanges) {
      for (final sourceFileEdit in sourceChange.edits) {
        if (!sourceFileEdit.file.endsWith('/main.dart')) {
          break;
        }

        final apiSourceEdits = sourceFileEdit.edits.map((sourceEdit) {
          return api.SourceEdit.fromChanges(
              sourceEdit.offset, sourceEdit.length, sourceEdit.replacement);
        }).toList();

        assists.add(api.CandidateFix.fromEdits(
          sourceChange.message,
          apiSourceEdits,
          sourceChange.selection?.offset,
          _convertLinkedEditGroups(sourceChange.linkedEditGroups),
        ));
      }
    }

    return assists;
  }

  /// Convert a list of the analysis server's [LinkedEditGroup]s into the API's
  /// equivalent.
  static List<api.LinkedEditGroup> _convertLinkedEditGroups(
      List<LinkedEditGroup> groups) {
    return groups?.map<api.LinkedEditGroup>((g) {
      return api.LinkedEditGroup(
        g.positions?.map((p) => p.offset)?.toList(),
        g.length,
        g.suggestions
            ?.map((s) => api.LinkedEditSuggestion(s.value, s.kind))
            ?.toList(),
      );
    })?.toList();
  }

  /// Cleanly shutdown the Analysis Server.
  Future<dynamic> shutdown() {
    // TODO(jcollins-g): calling dispose() sometimes prevents
    // --pause-isolates-on-exit from working; fix.
    return analysisServer.server
        .shutdown()
        .timeout(Duration(seconds: 1))
        .catchError((dynamic e) => null);
  }

  /// Internal implementation of the completion mechanism.
  Future<CompletionResults> _completeImpl(
      Map<String, String> sources, String sourceName, int offset) async {
    if (serverScheduler.queueCount > 0) {
      _logger
          .info('completeImpl: Scheduler queue: ${serverScheduler.queueCount}');
    }

    return serverScheduler.schedule(ClosureTask<CompletionResults>(() async {
      sources = _getOverlayMapWithPaths(sources);
      await _loadSources(sources);
      final id = await analysisServer.completion.getSuggestions(
        _getPathFromName(sourceName),
        offset,
      );
      final results = await getCompletionResults(id.id);
      await _unloadSources();
      return results;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<FixesResult> _getFixesImpl(
      Map<String, String> sources, String sourceName, int offset) async {
    sources = _getOverlayMapWithPaths(sources);
    final path = _getPathFromName(sourceName);

    if (serverScheduler.queueCount > 0) {
      _logger
          .fine('getFixesImpl: Scheduler queue: ${serverScheduler.queueCount}');
    }

    return serverScheduler.schedule(ClosureTask<FixesResult>(() async {
      final analysisCompleter = getAnalysisCompleteCompleter();
      await _loadSources(sources);
      await analysisCompleter.future;
      final fixes = await analysisServer.edit.getFixes(path, offset);
      await _unloadSources();
      return fixes;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Future<FormatResult> _formatImpl(String src, int offset) async {
    _logger.fine('FormatImpl: Scheduler queue: ${serverScheduler.queueCount}');

    return serverScheduler.schedule(ClosureTask<FormatResult>(() async {
      await _loadSources(<String, String>{mainPath: src});
      final result = await analysisServer.edit.format(mainPath, offset, 0);
      await _unloadSources();
      return result;
    }, timeoutDuration: _ANALYSIS_SERVER_TIMEOUT));
  }

  Map<String, String> _getOverlayMapWithPaths(Map<String, String> overlay) {
    final newOverlay = <String, String>{};
    for (final key in overlay.keys) {
      newOverlay[_getPathFromName(key)] = overlay[key];
    }
    return newOverlay;
  }

  String _getPathFromName(String sourceName) =>
      path.join(_sourceDirPath, sourceName);

  /// Warm up the analysis server to be ready for use.
  Future<api.CompleteResponse> warmup({bool useHtml = false}) =>
      complete(useHtml ? _WARMUP_SRC_HTML : _WARMUP_SRC, 10);

  final Set<String> _overlayPaths = <String>{};

  Future<void> _loadSources(Map<String, String> sources) async {
    if (_overlayPaths.isNotEmpty) {
      await _sendRemoveOverlays();
    }
    await _sendAddOverlays(sources);
    await analysisServer.analysis.setPriorityFiles(sources.keys.toList());
  }

  Future<dynamic> _unloadSources() {
    return Future.wait(<Future<dynamic>>[
      _sendRemoveOverlays(),
      analysisServer.analysis.setPriorityFiles(<String>[]),
    ]);
  }

  Future<dynamic> _sendAddOverlays(Map<String, String> overlays) {
    final params = <String, ContentOverlayType>{};
    for (final overlayPath in overlays.keys) {
      params[overlayPath] = AddContentOverlay(overlays[overlayPath]);
    }

    _logger.fine('About to send analysis.updateContent');
    _logger.fine('  ${params.keys}');

    _overlayPaths.addAll(params.keys);

    return analysisServer.analysis.updateContent(params);
  }

  Future<dynamic> _sendRemoveOverlays() {
    _logger.fine('About to send analysis.updateContent remove overlays:');
    _logger.fine('  $_overlayPaths');

    final params = <String, ContentOverlayType>{};
    for (final overlayPath in _overlayPaths) {
      params[overlayPath] = RemoveContentOverlay();
    }
    _overlayPaths.clear();
    return analysisServer.analysis.updateContent(params);
  }

  final Map<String, Completer<CompletionResults>> _completionCompleters =
      <String, Completer<CompletionResults>>{};

  void listenForCompletions() {
    analysisServer.completion.onResults.listen((CompletionResults result) {
      if (result.isLast) {
        final completer = _completionCompleters.remove(result.id);
        if (completer != null) {
          completer.complete(result);
        }
      }
    });
  }

  Future<CompletionResults> getCompletionResults(String id) {
    _completionCompleters[id] = Completer<CompletionResults>();
    return _completionCompleters[id].future;
  }

  final List<Completer<dynamic>> _analysisCompleters = <Completer<dynamic>>[];

  void listenForAnalysisComplete() {
    analysisServer.server.onStatus.listen((ServerStatus status) {
      if (status.analysis == null) return;

      if (!status.analysis.isAnalyzing) {
        for (final completer in _analysisCompleters) {
          completer.complete();
        }

        _analysisCompleters.clear();
      }
    });
  }

  Completer<dynamic> getAnalysisCompleteCompleter() {
    final completer = Completer<dynamic>();
    _analysisCompleters.add(completer);
    return completer;
  }

  final Map<String, List<AnalysisError>> _errors =
      <String, List<AnalysisError>>{};

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
    final errors = <AnalysisError>[];
    for (final e in _errors.values) {
      errors.addAll(e);
    }
    return errors;
  }
}
