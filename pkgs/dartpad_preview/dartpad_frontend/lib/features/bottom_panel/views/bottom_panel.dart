// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/events/sandbox_event.dart';
import '../models/console_entry.dart';
import 'bottom_panel_tabs.dart';
import 'console_panel.dart';
import 'inspector_panel.dart';
import 'problems_panel.dart';

/// The available tabs in the bottom panel.
enum BottomPanelTab {
  /// The problems tab showing diagnostics.
  problems,

  /// The console tab showing application logs.
  console,

  /// The Flutter widget inspector tab.
  inspector,
}

/// The bottom panel showing tabs with associated content panes.
class BottomPanel extends StatefulComponent {
  const BottomPanel({
    required this.events,
    required this.diagnostics,
    required this.hasMoreDiagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    required this.logs,
    required this.onClearConsole,
    super.key,
  });

  /// The global event bus.
  final AppEventBus events;

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

  @override
  State<BottomPanel> createState() => _BottomPanelState();

  @css
  static List<StyleRule> get styles => _BottomPanelState.styles;
}

class _BottomPanelState extends State<BottomPanel> {
  BottomPanelTab _activeTab = BottomPanelTab.problems;

  bool _isInspectorEnabled = false;
  StreamSubscription<SandboxChangedEvent>? _eventsSubscription;

  @override
  void initState() {
    super.initState();

    _eventsSubscription = component.events.on<SandboxChangedEvent>().listen((e) {
      setState(() {
        _isInspectorEnabled = e.sandbox != null && e.isFlutterApp;
      });
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _selectTab(BottomPanelTab tab) {
    if (tab == BottomPanelTab.inspector && !_isInspectorEnabled) {
      return;
    }
    setState(() {
      _activeTab = tab;
    });
  }

  @override
  Component build(BuildContext context) {
    var activeTab = _activeTab;
    if (activeTab == BottomPanelTab.inspector && !_isInspectorEnabled) {
      activeTab = BottomPanelTab.problems;
    }
    return div(classes: 'bottom-panel', [
      BottomPanelTabs(
        problemsCount: component.diagnostics.length,
        activeTab: activeTab,
        isInspectorEnabled: _isInspectorEnabled,
        onSelectTab: _selectTab,
        onClearConsole: component.onClearConsole,
      ),
      _buildContent(activeTab),
    ]);
  }

  Component _buildContent(BottomPanelTab activeTab) {
    return div(classes: 'bottom-panel-content', [
      switch (activeTab) {
        BottomPanelTab.problems => ProblemsPanel(
          diagnostics: component.diagnostics,
          hasMoreDiagnostics: component.hasMoreDiagnostics,
          activeFile: component.activeFile,
          onOpenDiagnostic: component.onOpenDiagnostic,
        ),
        BottomPanelTab.console => ConsolePanel(logs: component.logs),
        BottomPanelTab.inspector => InspectorPanel(events: component.events),
      },
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
    css('.bottom-panel .debug-console-panel, .bottom-panel .problems-panel').styles(
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      margin: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
