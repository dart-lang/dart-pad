// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/sandbox_event.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

class FakePreviewSandbox implements PreviewSandbox {
  final _extensionEventController = StreamController<({String kind, Map<String, Object?> data})>.broadcast();

  @override
  Stream<({String kind, Map<String, Object?> data})> get onExtensionEvent => _extensionEventController.stream;

  @override
  Future<String> invokeExtension(String method, Map<String, String> args) async {
    if (method == 'getRegisteredExtensions') {
      return '[]';
    }
    return '';
  }

  @override
  void dispose() {
    _extensionEventController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppEventBus events;

  setUp(() {
    events = AppEventBus();
  });

  tearDown(() async {
    await events.dispose();
  });

  testClient('switches to the console and invokes clear', (tester) async {
    var clearCalls = 0;
    tester.pumpComponent(
      BottomPanel(
        events: events,
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
        events: events,
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
        events: events,
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

  testClient('disables inspector tab when no sandbox or no flutter app is running', (tester) async {
    tester.pumpComponent(
      BottomPanel(
        events: events,
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
      ),
    );

    final inspectorTab = web.document.querySelector('.bottom-panel-tab:nth-child(3)')! as web.HTMLButtonElement;
    expect(inspectorTab.disabled, isTrue);

    final fakeSandbox = FakePreviewSandbox();
    events.dispatch(SandboxChangedEvent(fakeSandbox, isFlutterApp: true));
    await pumpEventQueue();

    expect(inspectorTab.disabled, isFalse);

    events.dispatch(const SandboxChangedEvent(null, isFlutterApp: false));
    await pumpEventQueue();

    expect(inspectorTab.disabled, isTrue);
    fakeSandbox.dispose();
  });

  testClient('switches to inspector tab when enabled and renders inspector panel', (tester) async {
    tester.pumpComponent(
      BottomPanel(
        events: events,
        diagnostics: const [],
        hasMoreDiagnostics: false,
        activeFile: '',
        logs: const [],
        onOpenDiagnostic: (_, _) {},
        onClearConsole: () {},
      ),
    );

    final inspectorTab = web.document.querySelector('.bottom-panel-tab:nth-child(3)')! as web.HTMLButtonElement;
    expect(inspectorTab.disabled, isTrue);

    final fakeSandbox = FakePreviewSandbox();
    events.dispatch(SandboxChangedEvent(fakeSandbox, isFlutterApp: true));
    await pumpEventQueue();

    expect(inspectorTab.disabled, isFalse);
    inspectorTab.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.debug-console-panel'), isNotNull);

    fakeSandbox.dispose();
  });
}
