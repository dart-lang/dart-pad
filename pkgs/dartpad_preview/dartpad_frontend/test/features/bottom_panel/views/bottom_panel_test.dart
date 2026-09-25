// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/bottom_panel/view_models/console_view_model.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/shared/events/open_console_event.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

void main() {
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

  testClient('shows one console error indicator until logs are cleared', (tester) async {
    final events = AppEventBus();
    final console = createConsole(events, () => tester.pumpComponent(const div([])));
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        console: console,
        onOpenDiagnostic: (_, _) {},
        events: events,
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
      BottomPanel(
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
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        console: console,
        onOpenDiagnostic: (_, _) {},
        events: events,
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
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        console: console,
        onOpenDiagnostic: (_, _) {},
        events: events,
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
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: true,
        console: console,
        onOpenDiagnostic: (_, _) {},
        events: events,
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
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        console: console,
        onOpenDiagnostic: (_, _) {},
        events: events,
      ),
    );

    expect(web.document.querySelector('.console-panel'), isNull);
    events.dispatch(const OpenConsoleEvent());
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel'), isNotNull);
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
