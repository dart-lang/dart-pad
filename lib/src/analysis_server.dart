// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around an analysis server instance
library services.analysis_server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'project.dart';
import 'protos/dart_services.pb.dart' as proto;
import 'pub.dart';
import 'scheduler.dart';
import 'utils.dart' as utils;

final Logger _logger = Logger('analysis_server');

/// Flag to determine whether we should dump the communication with the server
/// to stdout.
bool dumpServerMessages = false;

const String _warmupSrc = 'main() { int b = 2;  b++;   b. }';

// Use very long timeouts to ensure that the server has enough time to restart.
const Duration _analysisServerTimeout = Duration(seconds: 35);

class DartAnalysisServerWrapper extends AnalysisServerWrapper {
  DartAnalysisServerWrapper({required String dartSdkPath})
      : _sourceDirPath = ProjectTemplates.projectTemplates.dartPath,
        super(dartSdkPath);

  @override
  final String _sourceDirPath;

  @override
  String toString() => 'DartAnalysisServerWrapper<$_sourceDirPath>';
}

class FlutterAnalysisServerWrapper extends AnalysisServerWrapper {
  FlutterAnalysisServerWrapper({required String dartSdkPath})
      : _sourceDirPath = ProjectTemplates
            .projectTemplates
            // During analysis, we use the Firebase project template. The
            // Firebase template is separate from the Flutter template only to
            // keep Firebase references out of app initialization code at
            // runtime.
            .firebasePath,
        super(dartSdkPath);

  @override
  final String _sourceDirPath;

  @override
  String toString() => 'FlutterAnalysisServerWrapper<$_sourceDirPath>';
}

abstract class AnalysisServerWrapper {
  final String sdkPath;
  final TaskScheduler serverScheduler = TaskScheduler();

  bool _isInitialized = false;

  /// Instance to handle communication with the server.
  late AnalysisServer analysisServer;

  AnalysisServerWrapper(this.sdkPath);

  String get mainPath => _getPathFromName(kMainDart);

  String get _sourceDirPath;

  Future<void> init() async {
    if (_isInitialized) {
      throw StateError('AnalysisServerWrapper is already initialized');
    }

    _isInitialized = true;

    void onRead(String str) {
      if (dumpServerMessages) _logger.info('<-- $str');
    }

    void onWrite(String str) {
      if (dumpServerMessages) _logger.info('--> $str');
    }

    final serverArgs = <String>[
      '--client-id=DartPad',
      '--client-version=$_sdkVersion',
    ];
    _logger.info('Starting server; sdk: `$sdkPath`, args: $serverArgs');

    analysisServer = await AnalysisServer.create(
      onRead: onRead,
      onWrite: onWrite,
      sdkPath: sdkPath,
      serverArgs: serverArgs,
    );

    try {
      analysisServer.server.onError.listen((ServerError error) {
        _logger.severe('server error${error.isFatal ? ' (fatal)' : ''}',
            error.message, StackTrace.fromString(error.stackTrace));
      });
      await analysisServer.server.onConnected.first;
      await analysisServer.server.setSubscriptions(<String>['STATUS']);

      listenForCompletions();

      await analysisServer.analysis.setAnalysisRoots([_sourceDirPath], []);
      // Warmup.
      await _sendAddOverlays({mainPath: _warmupSrc});
      await _sendRemoveOverlays();
    } catch (err, st) {
      _logger.severe('Error starting analysis server ($sdkPath): $err.\n$st');
      rethrow;
    }
  }

  String get _sdkVersion {
    return File(path.join(sdkPath, 'version')).readAsStringSync().trim();
  }

  Future<int> get onExit {
    // Return when the analysis server exits. We introduce a delay so that when
    // we terminate the analysis server we can exit normally.
    return analysisServer.processCompleter.future.then((int code) {
      return Future<int>.delayed(const Duration(seconds: 1), () {
        return code;
      });
    });
  }

  Future<proto.CompleteResponse> complete(String src, int offset) async {
    return completeFiles({kMainDart: src}, Location(kMainDart, offset));
  }

  Future<proto.CompleteResponse> completeFiles(
      Map<String, String> sources, Location location) async {
    final results =
        await _completeImpl(sources, location.sourceName, location.offset);
    var suggestions = results.results;

    final source = sources[location.sourceName]!;
    final prefix = source.substring(results.replacementOffset, location.offset);
    suggestions = suggestions.where((suggestion) {
      return suggestion.completion
          .toLowerCase()
          .startsWith(prefix.toLowerCase());
    }).where((CompletionSuggestion suggestion) {
      // We do not want to enable arbitrary discovery of file system resources.

      // In order to avoid returning local file paths, we only allow returning
      // IMPORT kinds that are dart: or package: imports.
      if (suggestion.kind == 'IMPORT') {
        final completion = suggestion.completion;
        return completion.startsWith('dart:') ||
            completion.startsWith('package:');
      } else {
        return true;
      }
    }).toList();

    suggestions.sort((CompletionSuggestion x, CompletionSuggestion y) {
      if (x.relevance == y.relevance) {
        return x.completion.compareTo(y.completion);
      } else {
        return y.relevance.compareTo(x.relevance);
      }
    });

    return proto.CompleteResponse()
      ..replacementOffset = results.replacementOffset
      ..replacementLength = results.replacementLength
      ..completions
          .addAll(suggestions.map((CompletionSuggestion c) => proto.Completion()
            ..completion.addAll(c.toMap().map((key, value) {
              // TODO: Properly support Lists, Maps (this is a hack).
              if (value is Map || value is List) {
                value = json.encode(value);
              }
              return MapEntry(key.toString(), value.toString());
            }))));
  }

  Future<proto.FixesResponse> getFixes(String src, int offset) {
    return getFixesMulti({kMainDart: src}, Location(kMainDart, offset));
  }

  Future<proto.FixesResponse> getFixesMulti(
      Map<String, String> sources, Location location) async {
    final results =
        await _getFixesImpl(sources, location.sourceName, location.offset);
    final responseFixes = results.fixes.map((availableAnalysisErrorFixes) {
      return _convertAnalysisErrorFix(
          availableAnalysisErrorFixes, location.sourceName);
    });
    return proto.FixesResponse()..fixes.addAll(responseFixes);
  }

  Future<proto.AssistsResponse> getAssists(String src, int offset) async {
    return getAssistsMulti({kMainDart: src}, Location(kMainDart, offset));
  }

  Future<proto.AssistsResponse> getAssistsMulti(
      Map<String, String> sources, Location location) async {
    final sourceName = location.sourceName;
    final results = await _getAssistsImpl(sources, sourceName, location.offset);
    final fixes =
        _convertSourceChangesToCandidateFixes(results.assists, sourceName);
    return proto.AssistsResponse()..assists.addAll(fixes);
  }

  /// Format the source [src] of the single passed in file.  The [offset] is
  /// the current cursor location and a modified offset is returned if necessary
  /// to maintain the cursors original position in the formatted code.
  Future<proto.FormatResponse> format(String src, int offset) {
    return _formatImpl(src, offset).then((FormatResult editResult) {
      final edits = editResult.edits;

      edits.sort((SourceEdit e1, SourceEdit e2) =>
          -1 * e1.offset.compareTo(e2.offset));

      for (final edit in edits) {
        src = src.replaceRange(
            edit.offset, edit.offset + edit.length, edit.replacement);
      }

      return proto.FormatResponse()
        ..newString = src
        ..offset = editResult.selectionOffset;
    }).catchError((dynamic error) {
      _logger.fine('format error: $error');
      return proto.FormatResponse()
        ..newString = src
        ..offset = offset;
    });
  }

  Future<Map<String, String>> dartdoc(String src, int offset) {
    return dartdocMulti({kMainDart: src}, Location(kMainDart, offset));
  }

  Future<Map<String, String>> dartdocMulti(
      Map<String, String> sources, Location location) {
    _logger.fine('dartdoc: Scheduler queue: ${serverScheduler.queueCount}');

    sources = _getOverlayMapWithPaths(sources);
    final sourcepath = _getPathFromName(location.sourceName);

    return serverScheduler.schedule(ClosureTask<Map<String, String>>(() async {
      await _loadSources(sources);

      final result =
          await analysisServer.analysis.getHover(sourcepath, location.offset);
      await _unloadSources();

      if (result.hovers.isEmpty) {
        return const {};
      }

      final info = result.hovers.first;

      return {
        if (info.elementDescription != null)
          'description': info.elementDescription!,
        if (info.elementKind != null) 'kind': info.elementKind!,
        if (info.dartdoc != null) 'dartdoc': info.dartdoc!,
        if (info.containingClassDescription != null)
          'enclosingClassName': info.containingClassDescription!,
        if (info.containingLibraryName != null)
          'libraryName': info.containingLibraryName!,
        if (info.parameter != null) 'parameter': info.parameter!,
        if (info.isDeprecated != null)
          'deprecated': info.isDeprecated!.toString(),
        if (info.staticType != null) 'staticType': info.staticType!,
        if (info.propagatedType != null) 'propagatedType': info.propagatedType!,
      };
    }, timeoutDuration: _analysisServerTimeout));
  }

  Future<proto.AnalysisResults> analyze(String src) {
    return analyzeFiles({kMainDart: src});
  }

  Future<proto.AnalysisResults> analyzeFiles(Map<String, String> sources,
      {List<ImportDirective>? imports}) {
    _logger.fine('analyze: Scheduler queue: ${serverScheduler.queueCount}');

    return serverScheduler
        .schedule(ClosureTask<proto.AnalysisResults>(() async {
      sources = _getOverlayMapWithPaths(sources);
      await _loadSources(sources);
      final List<AnalysisError> errors = [];

      // Loop over all files and collect errors (sources now has filenames
      // with full paths as keys after _getOverlayMapWithPaths() call).
      for (final sourcepath in sources.keys) {
        errors.addAll(
            (await analysisServer.analysis.getErrors(sourcepath)).errors);
      }
      await _unloadSources();

      // Convert the issues to protos.
      final issues = errors.map((error) {
        final issue = proto.AnalysisIssue()
          ..kind = error.severity.toLowerCase()
          ..line = error.location.startLine
          ..message = utils.normalizeFilePaths(error.message)
          ..sourceName = path.basename(error.location.file)
          ..hasFixes = error.hasFix ?? false
          ..charStart = error.location.offset
          ..charLength = error.location.length
          ..diagnosticMessages.addAll(error.contextMessages?.map((m) =>
                  proto.DiagnosticMessage(
                      message: utils.normalizeFilePaths(m.message),
                      line: m.location.startLine,
                      charStart: m.location.offset,
                      charLength: m.location.length)) ??
              []);

        if (error.url != null) {
          issue.url = error.url!;
        }

        if (error.correction != null) {
          issue.correction = utils.normalizeFilePaths(error.correction!);
        }

        return issue;
      }).toList();

      issues.sort((a, b) {
        // Order issues by character position of the bug/warning.
        return a.charStart.compareTo(b.charStart);
      });

      // Ensure we have imports if they were not passed in.
      imports ??= getAllImportsForFiles(sources);

      // Calculate the package: imports (and defensively sanitize).
      final packageImports = {
        ...?imports?.filterSafePackages(),
      };

      return proto.AnalysisResults()
        ..issues.addAll(issues)
        ..packageImports.addAll(packageImports);
    }, timeoutDuration: _analysisServerTimeout));
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
      await _loadSources(sources);
      final AssistsResult assists;
      try {
        assists =
            await analysisServer.edit.getAssists(path, offset, 1 /* length */);
      } finally {
        await _unloadSources();
      }
      return assists;
    }, timeoutDuration: _analysisServerTimeout));
  }

  /// Convert between the Analysis Server type and the API protocol types.
  static proto.ProblemAndFixes _convertAnalysisErrorFix(
      AnalysisErrorFixes analysisFixes, String filename) {
    final problemMessage = analysisFixes.error.message;
    final problemOffset = analysisFixes.error.location.offset;
    final problemLength = analysisFixes.error.location.length;

    final possibleFixes = <proto.CandidateFix>[];

    for (final sourceChange in analysisFixes.fixes) {
      final edits = <proto.SourceEdit>[];

      // A fix that tries to modify other files is considered invalid.

      var invalidFix = false;
      for (final sourceFileEdit in sourceChange.edits) {
        // TODO(lukechurch): replace this with a more reliable test based on the
        // psuedo file name in Analysis Server
        if (!sourceFileEdit.file.endsWith('/$filename')) {
          invalidFix = true;
          break;
        }

        for (final sourceEdit in sourceFileEdit.edits) {
          edits.add(proto.SourceEdit()
            ..offset = sourceEdit.offset
            ..length = sourceEdit.length
            ..replacement = sourceEdit.replacement);
        }
      }
      if (!invalidFix) {
        final possibleFix = proto.CandidateFix()
          ..message = sourceChange.message
          ..edits.addAll(edits);
        possibleFixes.add(possibleFix);
      }
    }
    return proto.ProblemAndFixes()
      ..fixes.addAll(possibleFixes)
      ..problemMessage = problemMessage
      ..offset = problemOffset
      ..length = problemLength;
  }

  static List<proto.CandidateFix> _convertSourceChangesToCandidateFixes(
      List<SourceChange> sourceChanges, String filename) {
    final assists = <proto.CandidateFix>[];

    for (final sourceChange in sourceChanges) {
      for (final sourceFileEdit in sourceChange.edits) {
        if (!sourceFileEdit.file.endsWith('/$filename')) {
          break;
        }

        final sourceEdits = sourceFileEdit.edits.map((sourceEdit) {
          return proto.SourceEdit()
            ..offset = sourceEdit.offset
            ..length = sourceEdit.length
            ..replacement = sourceEdit.replacement;
        });

        final candidateFix = proto.CandidateFix();
        candidateFix.message = sourceChange.message;
        candidateFix.edits.addAll(sourceEdits);
        final selectionOffset = sourceChange.selection?.offset;
        if (selectionOffset != null) {
          candidateFix.selectionOffset = selectionOffset;
        }
        candidateFix.linkedEditGroups
            .addAll(_convertLinkedEditGroups(sourceChange.linkedEditGroups));
        assists.add(candidateFix);
      }
    }

    return assists;
  }

  /// Convert a list of the analysis server's [LinkedEditGroup]s into the API's
  /// equivalent.
  static Iterable<proto.LinkedEditGroup> _convertLinkedEditGroups(
      Iterable<LinkedEditGroup> groups) {
    return groups.map<proto.LinkedEditGroup>((g) {
      return proto.LinkedEditGroup()
        ..positions.addAll(g.positions.map((p) => p.offset).toList())
        ..length = g.length
        ..suggestions.addAll(g.suggestions
            .map((s) => proto.LinkedEditSuggestion()
              ..value = s.value
              ..kind = s.kind)
            .toList());
    });
  }

  /// Cleanly shutdown the Analysis Server.
  Future<void> shutdown() {
    // TODO(jcollins-g): calling dispose() sometimes prevents
    // --pause-isolates-on-exit from working; fix.
    return analysisServer.server
        .shutdown()
        .timeout(const Duration(seconds: 1))
        // At runtime, it appears that [ServerDomain.shutdown] returns a
        // `Future<Map<dynamic, dynamic>>`.
        .catchError((_) => {});
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
      final CompletionResults results;
      try {
        results = await getCompletionResults(id.id);
      } finally {
        await _unloadSources();
      }
      return results;
    }, timeoutDuration: _analysisServerTimeout));
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
      await _loadSources(sources);
      final FixesResult fixes;
      try {
        fixes = await analysisServer.edit.getFixes(path, offset);
      } finally {
        await _unloadSources();
      }
      return fixes;
    }, timeoutDuration: _analysisServerTimeout));
  }

  Future<FormatResult> _formatImpl(String src, int offset) async {
    _logger.fine('FormatImpl: Scheduler queue: ${serverScheduler.queueCount}');

    return serverScheduler.schedule(ClosureTask<FormatResult>(() async {
      await _loadSources({mainPath: src});
      final FormatResult result;
      try {
        result = await analysisServer.edit.format(mainPath, offset, 0);
      } finally {
        await _unloadSources();
      }
      return result;
    }, timeoutDuration: _analysisServerTimeout));
  }

  Map<String, String> _getOverlayMapWithPaths(Map<String, String> overlay) {
    final newOverlay = <String, String>{};
    for (final key in overlay.keys) {
      newOverlay[_getPathFromName(key)] = overlay[key]!;
    }
    return newOverlay;
  }

  String _getPathFromName(String sourceName) =>
      path.join(_sourceDirPath, sourceName);

  final Set<String> _overlayPaths = <String>{};

  /// Loads [sources] as file system overlays to the analysis server.
  ///
  /// The analysis server then begins to analyze these as priority files.
  Future<void> _loadSources(Map<String, String> sources) async {
    if (_overlayPaths.isNotEmpty) {
      throw StateError(
          'There should be no overlay paths while loading sources, but we '
          'have: $_overlayPaths');
    }
    await _sendAddOverlays(sources);
    await analysisServer.analysis.setPriorityFiles(sources.keys.toList());
  }

  Future<void> _unloadSources() async {
    await _sendRemoveOverlays();
    await analysisServer.analysis.setPriorityFiles([]);
  }

  /// Sends [overlays] to the analysis server.
  Future<void> _sendAddOverlays(Map<String, String> overlays) async {
    final contentOverlays = overlays.map((overlayPath, content) =>
        MapEntry(overlayPath, AddContentOverlay(content)));

    _logger.fine('About to send analysis.updateContent');
    _logger.fine('  ${contentOverlays.keys}');

    _overlayPaths.addAll(contentOverlays.keys);

    await analysisServer.analysis.updateContent(contentOverlays);
  }

  Future<void> _sendRemoveOverlays() async {
    _logger.fine('About to send analysis.updateContent remove overlays:');
    _logger.fine('  $_overlayPaths');

    final contentOverlays = {
      for (final overlayPath in _overlayPaths)
        overlayPath: RemoveContentOverlay()
    };
    _overlayPaths.clear();

    await analysisServer.analysis.updateContent(contentOverlays);
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
    final completer = Completer<CompletionResults>();
    _completionCompleters[id] = completer;
    return completer.future;
  }
}

class Location {
  final String sourceName;
  final int offset;

  const Location(this.sourceName, this.offset);
}
