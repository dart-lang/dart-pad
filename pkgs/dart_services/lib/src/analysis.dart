// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'common_server.dart';
import 'project_templates.dart' as project;
import 'project_templates.dart';
import 'pub.dart';
import 'sdk.dart';
import 'shared/model.dart' as api;
import 'utils.dart' as utils;

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
    final imports = getAllImportsFor(source);

    // TODO(srawlins): Do the work so that each unsupported input is its own
    // error with a proper SourceSpan.
    await _checkPackageReferences(imports);

    return analysisServer.analyze(source, imports: imports);
  }

  Future<api.CompleteResponse> complete(String source, int offset) async {
    await _checkPackageReferences(getAllImportsFor(source));

    return analysisServer.complete(source, offset);
  }

  Future<api.FixesResponse> fixes(String source, int offset) async {
    await _checkPackageReferences(getAllImportsFor(source));

    return analysisServer.fixes(source, offset);
  }

  Future<api.FormatResponse> format(String source, int? offset) async {
    return analysisServer.format(source, offset);
  }

  Future<api.DocumentResponse> dartdoc(String source, int offset) async {
    await _checkPackageReferences(getAllImportsFor(source));

    return analysisServer.dartdoc(source, offset);
  }

  /// Check that the set of packages referenced is valid.
  Future<void> _checkPackageReferences(List<ImportDirective> imports) async {
    final unsupportedImports = project.getUnsupportedImports(
      imports,
      sourceFiles: {kMainDart},
    );

    if (unsupportedImports.isNotEmpty) {
      final unsupportedUris =
          unsupportedImports.map((import) => import.uri.stringValue).toList();
      final plural = unsupportedUris.length == 1 ? 'import' : 'imports';
      throw BadRequest('unsupported $plural ${unsupportedUris.join(', ')}');
    }
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
        // During analysis, we use the Firebase project template. The Firebase
        // template is separate from the Flutter template only to keep Firebase
        // references out of app initialization code at runtime.
        projectPath =
            projectPath ?? ProjectTemplates.projectTemplates.firebasePath;

  String get mainPath => _getPathFromName(kMainDart);

  Future<void> init() async {
    final serverArgs = <String>['--client-id=DartPad'];
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
    final results = await _completeImpl(
      {kMainDart: source},
      kMainDart,
      offset,
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
    }).toList();

    suggestions.sort((CompletionSuggestion x, CompletionSuggestion y) {
      if (x.relevance == y.relevance) {
        return x.completion.compareTo(y.completion);
      } else {
        return y.relevance.compareTo(x.relevance);
      }
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
    final sourcepath = _getPathFromName(kMainDart);

    await _loadSources(_getOverlayMapWithPaths({kMainDart: src}));

    final result = await analysisServer.analysis.getHover(sourcepath, offset);

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

  Future<api.AnalysisResponse> analyze(
    String source, {
    List<ImportDirective>? imports,
  }) async {
    final sources = _getOverlayMapWithPaths({kMainDart: source});
    await _loadSources(sources);

    final errors = <AnalysisError>[];

    // Loop over all files and collect errors.
    for (final sourcepath in sources.keys) {
      errors
          .addAll((await analysisServer.analysis.getErrors(sourcepath)).errors);
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
        sourceName: path.basename(error.location.file),
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

    // Ensure we have imports if they were not passed in.
    imports ??= getAllImportsFor(source);

    return api.AnalysisResponse(
      issues: issues,
      packageImports: filterSafePackages(imports),
    );
  }

  /// Cleanly shutdown the Analysis Server.
  Future<void> shutdown() async {
    await analysisServer.server.shutdown().timeout(const Duration(seconds: 1));
  }

  Future<Suggestions2Result> _completeImpl(
      Map<String, String> sources, String sourceName, int offset) async {
    await _loadSources(_getOverlayMapWithPaths(sources));

    return await analysisServer.completion.getSuggestions2(
      _getPathFromName(sourceName),
      offset,
      500,
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
