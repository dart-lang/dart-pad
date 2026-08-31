// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/events/open_console_event.dart';
import '../models/console_entry.dart';
import 'bottom_panel_tabs.dart';
import 'console_panel.dart';
import 'problems_panel.dart';

/// The available tabs in the bottom panel.
enum BottomPanelTab {
  /// The problems tab showing diagnostics.
  problems,

  /// The debug console tab showing application logs.
  console,
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
    required this.events,
    this.contextMenu,
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

  /// Workspace events used to react to requests from the preview panel.
  final AppEventBus events;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  @override
  State<BottomPanel> createState() => _BottomPanelState();

  @css
  static List<StyleRule> get styles => _BottomPanelState.styles;
}

class _BottomPanelState extends State<BottomPanel> {
  BottomPanelTab _activeTab = BottomPanelTab.problems;
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
      if (mounted && _activeTab != BottomPanelTab.console) {
        _selectTab(BottomPanelTab.console);
      }
    });
  }

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
        onClearConsole: component.onClearConsole,
      ),
      _buildContent(),
    ]);
  }

  Component _buildContent() {
    return div(classes: 'bottom-panel-content', [
      switch (_activeTab) {
        BottomPanelTab.problems => ProblemsPanel(
          diagnostics: component.diagnostics,
          hasMoreDiagnostics: component.hasMoreDiagnostics,
          activeFile: component.activeFile,
          onOpenDiagnostic: component.onOpenDiagnostic,
        ),
        BottomPanelTab.console => ConsolePanel(
          logs: component.logs,
          onClear: component.onClearConsole,
          contextMenu: component.contextMenu,
        ),
      },
    ]);
  }

  @override
  void dispose() {
    unawaited(_openConsoleSubscription?.cancel());
    super.dispose();
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
    css('.bottom-panel .debug-console-panel, .bottom-panel .problems-panel').styles(
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      margin: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
