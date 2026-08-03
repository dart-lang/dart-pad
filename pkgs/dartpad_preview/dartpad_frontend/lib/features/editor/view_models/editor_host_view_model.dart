// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// @docImport '../../../app.dart';
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';

import '../codemirror/code_mirror_tab.dart';
import 'tabs_view_model.dart';

/// Manages the state for the editor host area: diagnostics from the language
/// server and bottom-panel visibility.
///
/// Created by [AppState] and fed to the view layer via [ListenableBuilder].
class EditorHostViewModel extends ChangeNotifier {
  EditorHostViewModel({required this.tabs});

  /// The editor tabs used to open and navigate to diagnostic locations.
  final TabsViewModel tabs;

  List<DiagnosticEntry> _diagnostics = const [];
  bool _showProblems = true;

  StreamSubscription<Map<String, dynamic>>? _diagnosticsSubscription;

  /// All current diagnostics, sorted by severity then location.
  List<DiagnosticEntry> get diagnostics => _diagnostics;

  /// Whether the problems panel is visible.
  bool get showProblems => _showProblems;

  /// Opens the file for [diagnostic] and navigates to its source position.
  Future<void> openDiagnostic(String fileName, Diagnostic diagnostic) async {
    await tabs.openTextFile(fileName);
    final tab = tabs.getTab(fileName);
    if (tab is CodeMirrorTab) {
      tab.goToPosition(diagnostic.line, diagnostic.character);
    }
  }

  /// Subscribes to diagnostic updates from [lsc].
  ///
  /// Cancels any previous subscription before attaching to the new client.
  void attachLanguageServer(LanguageServerClient lsc) {
    _diagnosticsSubscription?.cancel();
    _diagnostics = lsc.allDiagnostics;
    _diagnosticsSubscription = lsc.diagnosticsStream.listen((_) {
      _diagnostics = lsc.allDiagnostics;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Shows the problems panel.
  void showProblemsPanel() {
    _showProblems = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _diagnosticsSubscription?.cancel();
    super.dispose();
  }
}
