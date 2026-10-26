// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/bottom_panel/bottom_panel_state.dart';
import 'package:dartpad_frontend/features/bottom_panel/view_models/console_view_model.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/shared/events/open_console_event.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

void main() {
  PanelLayoutController createPanels(ClientTester tester, {bool isEmbedMode = false}) {
    final panels = PanelLayoutController(isEmbedMode: isEmbedMode);
    addTearDown(() async {
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      panels.dispose();
    });
    return panels;
  }

  ConsoleViewModel createConsole(AppEventBus events, void Function() unmount) {
    final console = ConsoleViewModel(events: events);
    addTearDown(() async {
      unmount();
      await pumpEventQueue();
      console.dispose();
      await events.dispose();
    });
    return console;
  }

  Component inSplitPanel(BottomPanel bottomPanel) {
    final panels = bottomPanel.panelController;
    return ListenableBuilder(
      listenable: panels.bottomListenable,
      builder: (_) => SplitPanel(
        state: panels.bottomSplit,
        onStateChanged: panels.updateBottomSplit,
        isVertical: true,
        canCollapseRight: true,
        left: const div([]),
        right: bottomPanel,
      ),
    );
  }

  testClient('shows one console error indicator until logs are cleared', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      inSplitPanel(
        BottomPanel(
          panelController: createPanels(tester),
          diagnostics: const [],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    final initialIndicator = consoleTab.querySelector('.bottom-panel-indicator') as web.HTMLElement?;
    expect(initialIndicator, isNotNull);
    expect(initialIndicator!.classList.contains('hidden'), isTrue);

    events.dispatch(const LogEvent('Info'));
    events.dispatch(const LogEvent('Warning', level: Level.WARNING));
    await pumpEventQueue();
    final warningIndicator = consoleTab.querySelector('.bottom-panel-indicator') as web.HTMLElement?;
    expect(warningIndicator!.classList.contains('hidden'), isTrue);

    events.dispatch(const LogEvent('Error', level: Level.SEVERE));
    await pumpEventQueue();
    final indicator = consoleTab.querySelector('.bottom-panel-indicator.error') as web.HTMLElement?;
    expect(indicator, isNotNull);
    expect(indicator!.classList.contains('hidden'), isFalse);
    expect(indicator.textContent, 'E');

    events.dispatch(const LogEvent('Another error', level: Level.SHOUT));
    events.dispatch(const LogEvent('Later info'));
    await pumpEventQueue();
    expect(consoleTab.querySelectorAll('.bottom-panel-indicator.error:not(.hidden)').length, 1);
    expect(consoleTab.textContent, 'ConsoleE');

    consoleTab.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel'), isNotNull);
    expect(consoleTab.querySelector('.bottom-panel-indicator.error:not(.hidden)'), isNotNull);

    events.dispatch(const LogEvent('While open'));
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel')!.textContent, contains('While open'));

    final clearButton = web.document.querySelector('button[aria-label="Clear console"]')! as web.HTMLButtonElement;
    clearButton.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel')!.textContent, contains('No output yet'));
    final clearedIndicator = consoleTab.querySelector('.bottom-panel-indicator') as web.HTMLElement?;
    expect(clearedIndicator, isNotNull);
    expect(clearedIndicator!.classList.contains('hidden'), isTrue);
  });

  testClient('renders problem indicators for diagnostics in the problems panel', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      inSplitPanel(
        BottomPanel(
          panelController: createPanels(tester),
          diagnostics: const [
            DiagnosticEntry(
              'main.dart',
              Diagnostic(
                severity: DiagnosticSeverity.error,
                line: 0,
                character: 0,
                message: 'Syntax error',
              ),
            ),
            DiagnosticEntry(
              'main.dart',
              Diagnostic(
                severity: DiagnosticSeverity.warning,
                line: 1,
                character: 0,
                message: 'Unused variable',
              ),
            ),
          ],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    final indicators = web.document.querySelectorAll('.problems-panel .bottom-panel-indicator');
    expect(indicators.length, 2);
    final first = indicators.item(0) as web.HTMLElement;
    expect(first.textContent, 'E');
    expect(first.classList.contains('error'), isTrue);
    final second = indicators.item(1) as web.HTMLElement;
    expect(second.textContent, 'W');
    expect(second.classList.contains('warning'), isTrue);
  });

  testClient('switches to the console and clears its logs', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    events.dispatch(const LogEvent('Running pub get in /'));
    await pumpEventQueue();
    tester.pumpComponent(
      inSplitPanel(
        BottomPanel(
          panelController: createPanels(tester),
          diagnostics: const [],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    expect(web.document.querySelector('.console-panel'), isNull);
    expect(web.document.querySelector('button[aria-label="Clear console"]'), isNull);

    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    consoleTab.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.console-panel')!.textContent, contains('Running pub get in /'));
    final clearButton = web.document.querySelector('button[aria-label="Clear console"]')! as web.HTMLButtonElement;
    expect(clearButton.disabled, isFalse);

    clearButton.click();
    await pumpEventQueue();

    expect(console.logs, isEmpty);
  });

  testClient('keeps clear enabled when the console is empty', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      inSplitPanel(
        BottomPanel(
          panelController: createPanels(tester),
          diagnostics: const [],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    consoleTab.click();
    await pumpEventQueue();

    final clearButton = web.document.querySelector('button[aria-label="Clear console"]')! as web.HTMLButtonElement;
    expect(clearButton.disabled, isFalse);
  });

  testClient('shows a diagnostic limit notice in the problems panel', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      inSplitPanel(
        BottomPanel(
          panelController: createPanels(tester),
          diagnostics: const [],
          hasMoreDiagnostics: true,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    expect(
      web.document.querySelector('.diagnostics-limit-notice')!.textContent,
      contains('Only the first 1,000 problems are shown.'),
    );
  });

  testClient('opens the Console when requested by another workspace component', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      inSplitPanel(
        BottomPanel(
          panelController: createPanels(tester),
          diagnostics: const [],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    expect(web.document.querySelector('.console-panel'), isNull);
    events.dispatch(const OpenConsoleEvent());
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel'), isNotNull);
  });

  testClient('tab clicks and console requests expand the shared split and survive remounts', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    final panels = createPanels(tester, isEmbedMode: true);
    final splitKey = GlobalStateKey<SplitPanelState>();
    Component layout() => ListenableBuilder(
      listenable: panels.bottomListenable,
      builder: (_) => SplitPanel(
        key: splitKey,
        state: panels.bottomSplit,
        onStateChanged: panels.updateBottomSplit,
        canCollapseRight: true,
        left: const div([]),
        right: BottomPanel(
          panelController: panels,
          diagnostics: const [],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );
    final showPanel = ValueNotifier(true);
    tester.pumpComponent(
      div([
        ListenableBuilder(listenable: showPanel, builder: (_) => showPanel.value ? layout() : const div([])),
      ]),
    );
    expect(web.document.querySelectorAll('[role="tab"]').length, 2);
    expect(web.document.querySelector('.bottom-panel-content'), isNull);

    (web.document.querySelectorAll('[role="tab"]').item(1) as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(splitKey.currentState!.state, const Split(0.75));
    expect(web.document.querySelector('.console-panel'), isNotNull);

    splitKey.currentState!.split(0.6);
    await pumpEventQueue();
    (web.document.querySelector('button[aria-label="Hide bottom panel"]') as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(panels.bottom, const BottomPanelCollapsed(BottomPanelTab.console, editorFraction: 0.6));
    expect(splitKey.currentState!.state, const RightCollapsed(0.6));
    expect(web.document.querySelectorAll('[role="tab"]').length, 2);

    showPanel.value = false;
    await pumpEventQueue();
    showPanel.value = true;
    await pumpEventQueue();
    expect(web.document.querySelector('.bottom-panel-content'), isNull);
    expect(splitKey.currentState!.state, const RightCollapsed(0.6));

    // Expanding the splitter preserves selection; a tab click or console event
    // would select Console again and could mask selection lost on remount.
    splitKey.currentState!.split();
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel'), isNotNull);
    expect(web.document.querySelector('[role="tab"][aria-selected="true"]')!.textContent, startsWith('Console'));
    splitKey.currentState!.collapseRight();
    await pumpEventQueue();
    events.dispatch(const OpenConsoleEvent());
    await pumpEventQueue();
    expect(splitKey.currentState!.state, const Split(0.6));
    expect(web.document.querySelector('.console-panel'), isNotNull);
    expect(web.document.querySelector('[role="tab"][aria-selected="true"]')!.textContent, startsWith('Console'));
  });

  testClient('hides content when collapsed in SplitPanel', (tester) {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      SplitPanel(
        initialState: const RightCollapsed(0.75),
        canCollapseRight: true,
        left: const div([]),
        right: BottomPanel(
          panelController: createPanels(tester, isEmbedMode: true),
          diagnostics: const [],
          hasMoreDiagnostics: false,
          console: console,
          onOpenDiagnostic: (_, _) {},
          events: events,
        ),
      ),
    );

    expect(web.document.querySelector('.bottom-panel.collapsed'), isNotNull);
    expect(web.document.querySelector('.bottom-panel-tabs'), isNotNull);
    expect(web.document.querySelector('.bottom-panel-content'), isNull);
  });
}
