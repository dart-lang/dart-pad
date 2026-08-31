// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/open_console_event.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('switches to the console and invokes clear', (tester) async {
    var clearCalls = 0;
    final events = AppEventBus();
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [ConsoleEntry(message: 'Running pub get in /', level: Level.INFO)],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () => clearCalls++,
        events: events,
      ),
    );

    expect(web.document.querySelector('.console-panel'), isNull);
    expect(web.document.querySelector('.bottom-panel-clear-btn'), isNull);

    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    consoleTab.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.console-panel')!.textContent, contains('Running pub get in /'));
    final clearButton = web.document.querySelector('.bottom-panel-clear-btn')! as web.HTMLButtonElement;
    expect(clearButton.disabled, isFalse);

    clearButton.click();
    await pumpEventQueue();
    expect(clearCalls, 1);
  });

  testClient('keeps clear enabled when the console is empty', (tester) async {
    final events = AppEventBus();
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
        events: events,
      ),
    );

    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    consoleTab.click();
    await pumpEventQueue();

    final clearButton = web.document.querySelector('.bottom-panel-clear-btn')! as web.HTMLButtonElement;
    expect(clearButton.disabled, isFalse);
  });

  testClient('shows a diagnostic limit notice in the problems panel', (tester) async {
    final events = AppEventBus();
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: true,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
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
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
        events: events,
      ),
    );

    expect(web.document.querySelector('.console-panel'), isNull);
    events.dispatch(const OpenConsoleEvent());
    await pumpEventQueue();
    expect(web.document.querySelector('.console-panel'), isNotNull);
  });
}
