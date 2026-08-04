// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'bottom_panel_tabs.dart';
import 'problems_panel.dart';

/// The available tabs in the bottom panel.
enum BottomPanelTab {
  /// The problems tab showing diagnostics.
  problems,
}

/// The bottom panel showing tabs with associated content panes.
class BottomPanel extends StatefulComponent {
  const BottomPanel({
    required this.diagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    super.key,
  });

  /// All current diagnostics from the language server.
  final List<DiagnosticEntry> diagnostics;

  /// The currently active editor file path, used to highlight matching rows.
  final String activeFile;

  /// Called when the user clicks a diagnostic row.
  final void Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  @override
  State<BottomPanel> createState() => _BottomPanelState();

  @css
  static List<StyleRule> get styles => _BottomPanelState.styles;
}

class _BottomPanelState extends State<BottomPanel> {
  BottomPanelTab _activeTab = BottomPanelTab.problems;

  void _selectTab(BottomPanelTab tab) {
    setState(() {
      _activeTab = tab;
    });
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'bottom-panel', [
      BottomPanelTabs(
        problemsCount: component.diagnostics.length,
        activeTab: _activeTab,
        onSelectTab: _selectTab,
      ),
      _buildContent(),
    ]);
  }

  Component _buildContent() {
    return div(
      classes: 'bottom-panel-content',
      [
        switch (_activeTab) {
          BottomPanelTab.problems => ProblemsPanel(
            diagnostics: component.diagnostics,
            activeFile: component.activeFile,
            onOpenDiagnostic: component.onOpenDiagnostic,
          ),
        },
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.bottom-panel').styles(
      display: .flex,
      height: 100.percent,
      flexDirection: .column,
      flex: const .shrink(0),
    ),
    css('.bottom-panel .bottom-panel-content').styles(
      display: .flex,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.bottom-panel .problems-panel').styles(
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      margin: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
