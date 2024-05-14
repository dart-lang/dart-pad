// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dartpad_shared/model.dart' as api;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'project_templates.dart';
import 'pub.dart';
import 'sdk.dart';
import 'utils.dart' as utils;
import 'utils.dart';

final Logger _logger = Logger('analysis_server');

class Analyzer {
  final Sdk sdk;

  late AnalysisServerWrapper analysisServer;

  Analyzer(this.sdk);

  Future<void> init() async {
    analysisServer = AnalysisServerWrapper(sdkPath: sdk.dartSdkPath);
    await analysisServer.init();

    unawaited(analysisServer.onExit.then((int code) {
      _logger.severe('analysis server exited, code: $code');
      if (code != 0) {
        exit(code);
      }
    }));
  }

  Future<api.AnalysisResponse> analyze(String source) async {
    return analysisServer.analyze(source);
  }

  Future<api.CompleteResponse> complete(String source, int offset) async {
    return analysisServer.complete(source, offset);
  }

  Future<api.FixesResponse> fixes(String source, int offset) async {
    return analysisServer.fixes(source, offset);
  }

  Future<api.FormatResponse> format(String source, int? offset) async {
    return analysisServer.format(source, offset);
  }

  Future<api.DocumentResponse> dartdoc(String source, int offset) async {
    return analysisServer.dartdoc(source, offset);
  }

  Future<void> shutdown() {
    return analysisServer.shutdown();
  }
}

class AnalysisServerWrapper {
  final String sdkPath;
  final String projectPath;

  /// Instance to handle communication with the server.
  late AnalysisServer analysisServer;

  AnalysisServerWrapper({
    required this.sdkPath,
    String? projectPath,
  }) :
        // During analysis, we use the Flutter project template.
        projectPath =
            projectPath ?? ProjectTemplates.projectTemplates.flutterPath;

  String get mainPath => _getPathFromName(kMainDart);

  Future<void> init() async {
    const serverArgs = <String>['--client-id=DartPad'];
    _logger.info('Starting analysis server '
        '(sdk: ${path.relative(sdkPath)}, args: ${serverArgs.join(' ')})');

    analysisServer = await AnalysisServer.create(
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

      await analysisServer.analysis.setAnalysisRoots([projectPath], []);
    } catch (err, st) {
      _logger.severe('Error starting analysis server ($sdkPath): $err.\n$st');
      rethrow;
    }
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

  Future<api.CompleteResponse> complete(String source, int offset) async {
    const maxResults = 500;

    final results = await _completeImpl(
      {kMainDart: source},
      kMainDart,
      offset,
      maxResults: maxResults,
    );

    final suggestions =
        results.suggestions.where((CompletionSuggestion suggestion) {
      // Filter suggestions that would require adding an import.
      return suggestion.isNotImported != true;
    }).where((CompletionSuggestion suggestion) {
      if (suggestion.kind != 'IMPORT') return true;

      // We do not want to enable arbitrary discovery of file system resources.
      // In order to avoid returning local file paths, we only allow returning
      // import kinds that are dart: or package: imports.
      if (suggestion.completion.startsWith('dart:')) {
        return true;
      }

      // Filter package suggestions to allowlisted packages.
      if (suggestion.completion.startsWith('package:')) {
        var packageName = suggestion.completion.substring('package:'.length);
        packageName = packageName.split('/').first;
        return isSupportedPackage(packageName);
      }

      return false;
    });

    return api.CompleteResponse(
      replacementOffset: results.replacementOffset,
      replacementLength: results.replacementLength,
      suggestions: suggestions.map((suggestion) {
        return api.CompletionSuggestion(
          kind: suggestion.kind,
          relevance: suggestion.relevance,
          completion: suggestion.completion,
          deprecated: suggestion.isDeprecated,
          selectionOffset: suggestion.selectionOffset,
          displayText: suggestion.displayText,
          parameterNames: suggestion.parameterNames,
          returnType: suggestion.returnType,
          elementKind: suggestion.element?.kind,
          elementParameters: suggestion.element?.parameters,
        );
      }).toList(),
    );
  }

  Future<api.FixesResponse> fixes(String src, int offset) async {
    final mainFile = _getPathFromName(kMainDart);

    await _loadSources({mainFile: src});

    final fixes = await analysisServer.edit.getFixes(mainFile, offset);
    final assists = await analysisServer.edit.getAssists(mainFile, offset, 1);

    final fixChanges = fixes.fixes.expand((fixes) => fixes.fixes).toList();
    final assistsChanges = assists.assists;

    // Filter any source changes that want to act on files other than main.dart.
    fixChanges.removeWhere(
        (change) => change.edits.any((edit) => edit.file != mainFile));
    assistsChanges.removeWhere(
        (change) => change.edits.any((edit) => edit.file != mainFile));

    return api.FixesResponse(
      fixes: fixChanges.map((change) {
        return change.toApiSourceChange();
      }).toList(),
      assists: assistsChanges.map((change) {
        return change.toApiSourceChange();
      }).toList(),
    );
  }

  /// Format the source [src] of the single passed in file. The [offset] is the
  /// current cursor location and a modified offset is returned if necessary to
  /// maintain the cursors original position in the formatted code.
  Future<api.FormatResponse> format(String src, int? offset) {
    return _formatImpl(src, offset).then((FormatResult editResult) {
      final edits = editResult.edits;

      edits.sort((SourceEdit e1, SourceEdit e2) =>
          -1 * e1.offset.compareTo(e2.offset));

      for (final edit in edits) {
        src = src.replaceRange(
            edit.offset, edit.offset + edit.length, edit.replacement);
      }

      return api.FormatResponse(
        source: src,
        offset: offset == null ? 0 : editResult.selectionOffset,
      );
    }).catchError((dynamic error) {
      _logger.fine('format error: $error');
      return api.FormatResponse(source: src, offset: offset);
    });
  }

  Future<api.DocumentResponse> dartdoc(String src, int offset) async {
    final sourcePath = _getPathFromName(kMainDart);

    await _loadSources(_getOverlayMapWithPaths({kMainDart: src}));

    final result = await analysisServer.analysis.getHover(sourcePath, offset);

    if (result.hovers.isEmpty) {
      return api.DocumentResponse();
    }

    final info = result.hovers.first;

    return api.DocumentResponse(
      dartdoc: info.dartdoc,
      containingLibraryName: info.containingLibraryName,
      elementDescription: info.elementDescription,
      elementKind: info.elementKind,
      deprecated: info.isDeprecated,
      propagatedType: info.propagatedType,
    );
  }

  Future<api.AnalysisResponse> analyze(String source) async {
    final sources = _getOverlayMapWithPaths({kMainDart: source});
    await _loadSources(sources);

    final errors = <AnalysisError>[];

    // Loop over all files and collect errors.
    for (final sourcePath in sources.keys) {
      errors
          .addAll((await analysisServer.analysis.getErrors(sourcePath)).errors);
    }

    final issues = errors.map((error) {
      final issue = api.AnalysisIssue(
        kind: error.severity.toLowerCase(),
        message: utils.normalizeFilePaths(error.message),
        code: error.code.toLowerCase(),
        location: api.Location(
          charStart: error.location.offset,
          charLength: error.location.length,
          line: error.location.startLine,
          column: error.location.startColumn,
        ),
        correction: error.correction == null
            ? null
            : utils.normalizeFilePaths(error.correction!),
        url: error.url,
        contextMessages: error.contextMessages?.map((m) {
          return api.DiagnosticMessage(
            message: utils.normalizeFilePaths(m.message),
            location: api.Location(
              charStart: m.location.offset,
              charLength: m.location.length,
              line: m.location.startLine,
              column: m.location.startColumn,
            ),
          );
        }).toList(),
      );

      return issue;
    }).toList();

    issues.sort((api.AnalysisIssue a, api.AnalysisIssue b) {
      // Order issues by severity.
      if (a.severity != b.severity) {
        return b.severity - a.severity;
      }

      // Then by character position.
      return a.location.charStart.compareTo(b.location.charStart);
    });

    final imports = getAllImportsFor(source);
    final importIssues = <api.AnalysisIssue>[];

    for (final import in imports) {
      if (import.dartImport) {
        final libraryName = import.packageName;
        if (!isSupportedCoreLibrary(libraryName)) {
          importIssues.add(api.AnalysisIssue(
            kind: 'error',
            message: "Unsupported library on the web: 'dart:$libraryName'.",
            correction: 'Try removing the import and usages of the library.',
            location: import.getLocation(source),
          ));
        } else if (isDeprecatedCoreWebLibrary(libraryName)) {
          importIssues.add(api.AnalysisIssue(
            kind: 'info', // TODO(parlough): Expand to 'warning' in future.
            message: "Deprecated core web library: 'dart:$libraryName'.",
            correction: 'Try using static JS interop instead.',
            url: 'https://dart.dev/go/next-gen-js-interop',
            location: import.getLocation(source),
          ));
        }
      } else if (import.packageImport) {
        final packageName = import.packageName;

        if (isFirebasePackage(packageName)) {
          importIssues.add(api.AnalysisIssue(
            kind: 'warning',
            message: 'Firebase is no longer supported by DartPad.',
            url:
                'https://github.com/dart-lang/dart-pad/wiki/Package-and-plugin-support#deprecated-firebase-packages',
            location: import.getLocation(source),
          ));
        } else if (isDeprecatedPackage(packageName)) {
          importIssues.add(api.AnalysisIssue(
            kind: 'warning',
            message: "Deprecated package: 'package:$packageName'.",
            correction: 'Try removing the import and usages of the package.',
            url: 'https://github.com/dart-lang/dart-pad/wiki/'
                'Package-and-plugin-support#deprecated-packages',
            location: import.getLocation(source),
          ));
        } else if (!isSupportedPackage(packageName)) {
          importIssues.add(api.AnalysisIssue(
            kind: 'warning',
            message: "Unsupported package: 'package:$packageName'.",
            location: import.getLocation(source),
          ));
        }
      } else {
        importIssues.add(api.AnalysisIssue(
          kind: 'error',
          message: 'Import type not supported.',
          location: import.getLocation(source),
        ));
      }
    }

    return api.AnalysisResponse(issues: [...importIssues, ...issues]);
  }

  /// Cleanly shutdown the Analysis Server.
  Future<void> shutdown() async {
    await analysisServer.server.shutdown().timeout(const Duration(seconds: 1));
  }

  Future<Suggestions2Result> _completeImpl(
    Map<String, String> sources,
    String sourceName,
    int offset, {
    required int maxResults,
  }) async {
    await _loadSources(_getOverlayMapWithPaths(sources));

    return await analysisServer.completion.getSuggestions2(
      _getPathFromName(sourceName),
      offset,
      maxResults,
    );
  }

  Future<FormatResult> _formatImpl(String src, int? offset) async {
    await _loadSources({mainPath: src});
    return await analysisServer.edit.format(mainPath, offset ?? 0, 0);
  }

  Map<String, String> _getOverlayMapWithPaths(Map<String, String> overlay) {
    final newOverlay = <String, String>{};
    for (final key in overlay.keys) {
      newOverlay[_getPathFromName(key)] = overlay[key]!;
    }
    return newOverlay;
  }

  String _getPathFromName(String sourceName) =>
      path.join(projectPath, sourceName);

  List<String> _overlayPaths = [];

  /// Loads [sources] as file system overlays to the analysis server.
  ///
  /// The analysis server then begins to analyze these as priority files.
  Future<void> _loadSources(Map<String, String> sources) async {
    // Remove all the existing overlays.
    final contentOverlays = <String, ContentOverlayType>{
      for (final overlayPath in _overlayPaths)
        overlayPath: RemoveContentOverlay()
    };

    // Add (or replace) new overlays for the given files.
    for (final sourceEntry in sources.entries) {
      contentOverlays[sourceEntry.key] = AddContentOverlay(sourceEntry.value);
    }

    await analysisServer.analysis.updateContent(contentOverlays);
    await analysisServer.analysis.setPriorityFiles(sources.keys.toList());

    _overlayPaths = sources.keys.toList();
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

extension SourceChangeExtension on SourceChange {
  api.SourceChange toApiSourceChange() {
    return api.SourceChange(
      message: message,
      edits: edits
          .expand((fileEdit) => fileEdit.edits)
          .map(
            (edit) => api.SourceEdit(
              offset: edit.offset,
              length: edit.length,
              replacement: edit.replacement,
            ),
          )
          .toList(),
      linkedEditGroups: linkedEditGroups.map((editGroup) {
        return api.LinkedEditGroup(
          offsets: editGroup.positions.map((pos) => pos.offset).toList(),
          length: editGroup.length,
          suggestions: editGroup.suggestions.map((sug) {
            return api.LinkedEditSuggestion(
              value: sug.value,
              kind: sug.kind,
            );
          }).toList(),
        );
      }).toList(),
      selectionOffset: selection?.offset,
    );
  }
}

extension AnnotatedNodeExtension on AnnotatedNode {
  api.Location getLocation(String source) {
    final lines = Lines(source);
    final start = firstTokenAfterCommentAndMetadata;

    return api.Location(
      charStart: start.charOffset,
      charLength: endToken.charEnd - start.charOffset,
      line: lines.lineForOffset(start.charOffset),
      column: lines.columnForOffset(start.charOffset),
    );
  }
}
