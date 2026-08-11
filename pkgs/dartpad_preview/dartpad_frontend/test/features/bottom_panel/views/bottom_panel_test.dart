// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('switches to the console and invokes clear', (tester) async {
    var clearCalls = 0;
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [ConsoleEntry(message: 'Running pub get in /', level: Level.INFO)],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () => clearCalls++,
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
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
      ),
    );

    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    consoleTab.click();
    await pumpEventQueue();

    final clearButton = web.document.querySelector('.bottom-panel-clear-btn')! as web.HTMLButtonElement;
    expect(clearButton.disabled, isFalse);
  });

  testClient('shows a diagnostic limit notice in the problems panel', (tester) async {
    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: true,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
      ),
    );

    expect(
      web.document.querySelector('.diagnostics-limit-notice')!.textContent,
      contains('Only the first 1,000 problems are shown.'),
    );
  });
}
