// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';

import '../../editor/codemirror/code_mirror_tab.dart';
import '../../editor/view_models/tabs_view_model.dart';

/// Manages diagnostics from the language server and navigation to their source
/// locations.
final class DiagnosticsViewModel extends ChangeNotifier {
  DiagnosticsViewModel({required this.tabs});

  /// The maximum number of diagnostics rendered in the problems panel.
  static const maxDisplayedDiagnostics = 1000;

  /// The editor tabs used to open and navigate to diagnostic locations.
  final TabsViewModel tabs;

  List<DiagnosticEntry> _diagnostics = const [];
  List<DiagnosticEntry> _languageServerDiagnostics = const [];
  List<DiagnosticEntry> _importDiagnostics = const [];
  String? _projectRoot;

  StreamSubscription<Map<String, Object?>>? _diagnosticsSubscription;
  StreamSubscription<WorkspaceChangeEvent>? _workspaceSubscription;
  Timer? _importRefreshTimer;
  int _importRefreshGeneration = 0;

  /// How long to wait after a relevant workspace change before recomputing import diagnostics.
  static const importRefreshDelay = Duration(milliseconds: 300);

  /// The first [maxDisplayedDiagnostics] diagnostics, sorted by severity then
  /// location.
  ///
  /// Limiting the entries keeps the problems panel responsive when the
  /// language server reports a very large number of diagnostics.
  List<DiagnosticEntry> get diagnostics => _diagnostics.take(maxDisplayedDiagnostics).toList(growable: false);

  /// Whether some diagnostics are omitted from the problems panel.
  bool get hasMoreDiagnostics => _diagnostics.length > maxDisplayedDiagnostics;

  /// Replaces the problems recorded while importing the project.
  ///
  /// These remain listed when the language server is absent or detached.
  void setImportDiagnostics(List<DiagnosticEntry> entries) {
    _importDiagnostics = List.unmodifiable(entries);
    _rebuildDiagnostics();
    notifyListeners();
  }

  /// Recomputes the import problems with [computeImportDiagnostics] after workspace changes
  /// that can affect them.
  ///
  /// Pubspec edits and any added, removed, or moved resource trigger a recompute, because
  /// a dependency's availability depends on which package files exist. Recomputes are
  /// debounced. Cancels any previous watch.
  void watchImportDiagnostics(
    WorkspaceResourceApi workspace, {
    required Future<List<DiagnosticEntry>> Function(WorkspaceResourceApi workspace) computeImportDiagnostics,
  }) {
    _cancelImportWatch();
    _workspaceSubscription = workspace.changeEvents.listen((event) {
      if (!_affectsImportDiagnostics(event)) {
        return;
      }
      _importRefreshTimer?.cancel();
      _importRefreshTimer = Timer(importRefreshDelay, () {
        refreshImportDiagnostics(workspace, computeImportDiagnostics);
      });
    });
  }

  /// Replaces the import problems with the result of [computeImportDiagnostics].
  ///
  /// A newer refresh, a new watch, or [dispose] discards this result.
  Future<void> refreshImportDiagnostics(
    WorkspaceResourceApi workspace,
    Future<List<DiagnosticEntry>> Function(WorkspaceResourceApi workspace) computeImportDiagnostics,
  ) async {
    final generation = ++_importRefreshGeneration;
    final entries = await computeImportDiagnostics(workspace);
    if (generation != _importRefreshGeneration) {
      return;
    }
    setImportDiagnostics(entries);
  }

  static bool _affectsImportDiagnostics(WorkspaceChangeEvent event) {
    if (event.type != WorkspaceChangeEventType.modify) {
      return true;
    }
    final basename = basenameWorkspacePath(event.path);
    return basename == 'pubspec.yaml' || basename == 'pubspec_overrides.yaml';
  }

  void _cancelImportWatch() {
    _workspaceSubscription?.cancel();
    _workspaceSubscription = null;
    _importRefreshTimer?.cancel();
    _importRefreshTimer = null;
    _importRefreshGeneration++;
  }

  /// Opens the file for [diagnostic] and navigates to its source position.
  Future<void> openDiagnostic(String fileName, Diagnostic diagnostic) async {
    await tabs.openWorkspaceFile(fileName);
    final tab = tabs.getTab(fileName);
    if (tab is CodeMirrorTab) {
      tab.goToPosition(diagnostic.line, diagnostic.character);
    }
  }

  /// Subscribes to diagnostic updates from [lsc].
  ///
  /// Cancels any previous subscription before attaching to the new client.
  void attachLanguageServer(
    LanguageServerClient lsc, {
    String? projectRoot,
  }) {
    _diagnosticsSubscription?.cancel();
    _projectRoot = projectRoot == null ? null : normalizeWorkspacePath(projectRoot);
    _updateDiagnostics(lsc);
    _diagnosticsSubscription = lsc.diagnosticsStream.listen((_) {
      _updateDiagnostics(lsc);
      notifyListeners();
    });
    notifyListeners();
  }

  void _updateDiagnostics(LanguageServerClient lsc) {
    _languageServerDiagnostics = lsc.allDiagnostics
        .where(
          (entry) => _projectRoot == null || isWithinWorkspaceFolder(entry.fileName, _projectRoot!),
        )
        .toList(growable: false);
    _rebuildDiagnostics();
  }

  /// Merges import and language server problems, sorted by severity then location.
  void _rebuildDiagnostics() {
    final byFile = <String, List<Diagnostic>>{};
    for (final entry in [..._importDiagnostics, ..._languageServerDiagnostics]) {
      byFile.putIfAbsent(entry.fileName, () => []).add(entry.diagnostic);
    }
    _diagnostics = sortedDiagnosticEntries(byFile);
  }

  void detachLanguageServer() {
    _diagnosticsSubscription?.cancel();
    _diagnosticsSubscription = null;
    _languageServerDiagnostics = const [];
    _rebuildDiagnostics();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelImportWatch();
    _diagnosticsSubscription?.cancel();
    super.dispose();
  }
}
