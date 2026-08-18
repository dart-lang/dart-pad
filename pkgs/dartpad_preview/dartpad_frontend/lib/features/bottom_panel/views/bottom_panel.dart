// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../preview/view_models/preview_view_model.dart';
import '../models/console_entry.dart';
import 'bottom_panel_tabs.dart';
import 'console_panel.dart';
import 'devtools_panel.dart';
import 'problems_panel.dart';

/// The available tabs in the bottom panel.
enum BottomPanelTab {
  /// The problems tab showing diagnostics.
  problems,

  /// The debug console tab showing application logs.
  console,

  /// The DevTools tab embedding Flutter DevTools.
  devtools,
}

/// The bottom panel showing tabs with associated content panes.
class BottomPanel extends StatefulComponent {
  const BottomPanel({
    required this.diagnostics,
    required this.hasMoreDiagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    required this.logs,
    required this.onClearConsole,
    this.previewViewModel,
    super.key,
  });

  /// All current diagnostics from the language server.
  final List<DiagnosticEntry> diagnostics;

  /// Whether diagnostics are omitted from the problems panel.
  final bool hasMoreDiagnostics;

  /// The currently active editor file path, used to highlight matching rows.
  final String activeFile;

  /// Called when the user clicks a diagnostic row.
  final void Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  /// Application log lines shown in the debug console.
  final List<ConsoleEntry> logs;

  /// Clears the debug output.
  final void Function() onClearConsole;

  /// The preview view model to communicate with the running sandbox.
  final PreviewViewModel? previewViewModel;

  @override
  State<BottomPanel> createState() => _BottomPanelState();

  @css
  static List<StyleRule> get styles => _BottomPanelState.styles;
}

class _BottomPanelState extends State<BottomPanel> {
  BottomPanelTab _activeTab = BottomPanelTab.problems;

  bool get _isDevToolsEnabled => component.previewViewModel?.isRunning ?? false;

  @override
  void initState() {
    super.initState();
    component.previewViewModel?.addListener(_onPreviewChanged);
  }

  @override
  void didUpdateComponent(BottomPanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.previewViewModel != component.previewViewModel) {
      oldComponent.previewViewModel?.removeListener(_onPreviewChanged);
      component.previewViewModel?.addListener(_onPreviewChanged);
    }
  }

  @override
  void dispose() {
    component.previewViewModel?.removeListener(_onPreviewChanged);
    super.dispose();
  }

  void _onPreviewChanged() {
    if (!_isDevToolsEnabled && _activeTab == BottomPanelTab.devtools) {
      _selectTab(BottomPanelTab.problems);
    } else {
      setState(() {});
    }
  }

  void _selectTab(BottomPanelTab tab) {
    if (tab == BottomPanelTab.devtools && !_isDevToolsEnabled) {
      return;
    }
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
        onClearConsole: component.onClearConsole,
        isDevToolsEnabled: _isDevToolsEnabled,
      ),
      _buildContent(),
    ]);
  }

  Component _buildContent() {
    return div(classes: 'bottom-panel-content', [
      div(
        classes: 'bottom-panel-tab-pane',
        styles: _activeTab == BottomPanelTab.problems ? null : const Styles(display: Display.none),
        [
          ProblemsPanel(
            diagnostics: component.diagnostics,
            hasMoreDiagnostics: component.hasMoreDiagnostics,
            activeFile: component.activeFile,
            onOpenDiagnostic: component.onOpenDiagnostic,
          ),
        ],
      ),
      div(
        classes: 'bottom-panel-tab-pane',
        styles: _activeTab == BottomPanelTab.console ? null : const Styles(display: Display.none),
        [
          ConsolePanel(logs: component.logs),
        ],
      ),
      div(
        classes: 'bottom-panel-tab-pane',
        styles: _activeTab == BottomPanelTab.devtools ? null : const Styles(display: Display.none),
        [
          DevToolsPanel(previewViewModel: component.previewViewModel),
        ],
      ),
    ]);
  }

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
    css('.bottom-panel .bottom-panel-tab-pane').styles(
      display: .flex,
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.bottom-panel .debug-console-panel, .bottom-panel .problems-panel, .bottom-panel .devtools-panel').styles(
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      margin: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
