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
class DiagnosticsViewModel extends ChangeNotifier {
  DiagnosticsViewModel({required this.tabs});

  /// The maximum number of diagnostics rendered in the problems panel.
  static const maxDisplayedDiagnostics = 1000;

  /// The editor tabs used to open and navigate to diagnostic locations.
  final TabsViewModel tabs;

  List<DiagnosticEntry> _diagnostics = const [];

  StreamSubscription<Map<String, dynamic>>? _diagnosticsSubscription;

  /// The first [maxDisplayedDiagnostics] diagnostics, sorted by severity then
  /// location.
  ///
  /// Limiting the entries keeps the problems panel responsive when the
  /// language server reports a very large number of diagnostics.
  List<DiagnosticEntry> get diagnostics => _diagnostics.take(maxDisplayedDiagnostics).toList(growable: false);

  /// Whether some diagnostics are omitted from the problems panel.
  bool get hasMoreDiagnostics => _diagnostics.length > maxDisplayedDiagnostics;

  /// Opens the file for [diagnostic] and navigates to its source position.
  Future<void> openDiagnostic(String fileName, Diagnostic diagnostic) async {
    await tabs.openFileWithErrorReporting(fileName);
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

  @override
  void dispose() {
    _diagnosticsSubscription?.cancel();
    super.dispose();
  }
}
