// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/components/split_panel.dart';
import '../../shared/events/open_console_event.dart';
import '../../shared/panel_layout_controller.dart';
import '../bottom_panel_state.dart';
import '../view_models/console_view_model.dart';
import 'bottom_panel_tabs.dart';
import 'console_panel.dart';
import 'problems_panel.dart';

/// The bottom panel showing tabs with associated content panes.
final class BottomPanel extends StatefulComponent {
  const BottomPanel({
    required this.diagnostics,
    required this.hasMoreDiagnostics,
    required this.onOpenDiagnostic,
    required this.console,
    required this.events,
    required this.panelController,
    super.key,
  });

  /// All current diagnostics from the language server.
  final List<DiagnosticEntry> diagnostics;

  /// Whether diagnostics are omitted from the problems panel.
  final bool hasMoreDiagnostics;

  /// Called when the user clicks a diagnostic row.
  final void Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  /// Console state used by the indicator and the visible console pane.
  final ConsoleViewModel console;

  /// Shared selection, expansion, and size for the bottom panel.
  final PanelLayoutController panelController;

  /// Workspace events used to react to requests from the preview panel.
  final AppEventBus events;

  @override
  State<BottomPanel> createState() => _BottomPanelState();

  @css
  static List<StyleRule> get styles => _BottomPanelState.styles;
}

final class _BottomPanelState extends State<BottomPanel> {
  StreamSubscription<OpenConsoleEvent>? _openConsoleSubscription;

  @override
  void initState() {
    super.initState();
    _listenForOpenConsole();
  }

  @override
  void didUpdateComponent(BottomPanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.events, component.events)) {
      unawaited(_openConsoleSubscription?.cancel());
      _listenForOpenConsole();
    }
  }

  void _listenForOpenConsole() {
    _openConsoleSubscription = component.events.on<OpenConsoleEvent>().listen((_) {
      if (!mounted) {
        return;
      }
      component.panelController.openBottomPanel(BottomPanelTab.console);
    });
  }

  @override
  void dispose() {
    unawaited(_openConsoleSubscription?.cancel());
    super.dispose();
  }

  @override
  Component build(BuildContext context) => ListenableBuilder(
    listenable: component.panelController.bottomListenable,
    builder: _buildPanel,
  );

  Component _buildPanel(BuildContext context) {
    final panel = SplitPanel.of(context);
    final bottom = component.panelController.bottom;
    final isCollapsed = !bottom.isExpanded;
    return div(
      classes: 'bottom-panel${isCollapsed ? ' collapsed' : ''}',
      [
        BottomPanelTabs(
          problemsCount: component.diagnostics.length,
          console: component.console,
          activeTab: bottom.selectedTab,
          isCollapsed: isCollapsed,
          onSelectTab: component.panelController.openBottomPanel,
          onCollapse: panel != null && panel.canCollapse ? component.panelController.collapseBottomPanel : null,
        ),
        if (!isCollapsed) _buildContent(),
      ],
    );
  }

  Component _buildContent() {
    return div(classes: 'bottom-panel-content', [
      switch (component.panelController.bottom.selectedTab) {
        BottomPanelTab.problems => ProblemsPanel(
          diagnostics: component.diagnostics,
          hasMoreDiagnostics: component.hasMoreDiagnostics,
          onOpenDiagnostic: component.onOpenDiagnostic,
        ),
        BottomPanelTab.console => ListenableBuilder(
          listenable: component.console,
          builder: (_) => ConsolePanel(logs: component.console.logs),
        ),
      },
    ]);
  }

  static List<StyleRule> get styles => [
    css('.bottom-panel').styles(
      display: .flex,
      flexDirection: .column,
      flex: const .shrink(0),
    ),
    css('.bottom-panel .bottom-panel-content').styles(
      display: .flex,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.bottom-panel .debug-console-panel, .bottom-panel .problems-panel').styles(
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      margin: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
