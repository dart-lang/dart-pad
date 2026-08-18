// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/view_models/preview_view_model.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

class FakePreviewViewModel extends ChangeNotifier implements PreviewViewModel {
  FakePreviewViewModel({this.isRunning = false});

  @override
  final bool isRunning;

  @override
  PreviewSandbox? get sandbox => null;

  @override
  Uri? get packageUri => null;

  @override
  PreviewState get state => PreviewInitial();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testClient('always keeps all tab contents in the DOM and toggles display: none', (tester) async {
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

    // All panels are present in the DOM simultaneously
    final problemsPane = web.document.querySelector('.bottom-panel-tab-pane:nth-child(1)')! as web.HTMLElement;
    final consolePane = web.document.querySelector('.bottom-panel-tab-pane:nth-child(2)')! as web.HTMLElement;
    final devtoolsPane = web.document.querySelector('.bottom-panel-tab-pane:nth-child(3)')! as web.HTMLElement;

    expect(problemsPane.style.display, isEmpty);
    expect(consolePane.style.display, 'none');
    expect(devtoolsPane.style.display, 'none');
    expect(web.document.querySelector('.bottom-panel-clear-btn'), isNull);

    // Switch to console tab
    final consoleTab = web.document.querySelector('.bottom-panel-tab:nth-child(2)')! as web.HTMLButtonElement;
    consoleTab.click();
    await pumpEventQueue();

    expect(problemsPane.style.display, 'none');
    expect(consolePane.style.display, isEmpty);
    expect(devtoolsPane.style.display, 'none');

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

  testClient('disables devtools tab when sandbox is not running', (tester) async {
    final preview = FakePreviewViewModel(isRunning: false);

    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
        previewViewModel: preview,
      ),
    );

    final devtoolsTab = web.document.querySelector('.bottom-panel-tab:nth-child(3)')! as web.HTMLButtonElement;
    expect(devtoolsTab.disabled, isTrue);
    expect(devtoolsTab.className, contains('disabled'));

    final devtoolsPane = web.document.querySelector('.bottom-panel-tab-pane:nth-child(3)')! as web.HTMLElement;
    expect(devtoolsPane.style.display, 'none');

    // Clicking disabled tab does nothing
    devtoolsTab.click();
    await pumpEventQueue();

    expect(devtoolsPane.style.display, 'none');
  });

  testClient('enables devtools tab and switches to it when sandbox is running', (tester) async {
    final preview = FakePreviewViewModel(isRunning: true);

    tester.pumpComponent(
      BottomPanel(
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
        previewViewModel: preview,
      ),
    );

    final devtoolsTab = web.document.querySelector('.bottom-panel-tab:nth-child(3)')! as web.HTMLButtonElement;
    expect(devtoolsTab.disabled, isFalse);
    expect(devtoolsTab.className, isNot(contains('disabled')));

    final devtoolsPane = web.document.querySelector('.bottom-panel-tab-pane:nth-child(3)')! as web.HTMLElement;
    expect(devtoolsPane.style.display, 'none');

    devtoolsTab.click();
    await pumpEventQueue();

    expect(devtoolsPane.style.display, isEmpty);
    final iframe = web.document.querySelector('.devtools-iframe')! as web.HTMLIFrameElement;
    expect(iframe.src, contains('devtools/index.html'));
  });
}
