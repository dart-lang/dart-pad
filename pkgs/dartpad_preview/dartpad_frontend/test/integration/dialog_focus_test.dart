// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// App-level dialog and shortcut focus behaviour
@TestOn('browser')
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

import '../features/persistence/persistence_fixture.dart';
import '../features/startup/initial_project_state_test.dart' show contents;
import '../worker_fixture.dart';

void main() {
  TestWorker.captureAssetBaseUrl();
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  testClient('command palette shortcut closes the shortcuts dialog', (tester) async {
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
            WorkspaceRepository(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              workspaceResourceApi: localApi!,
              workspaceFuture: Completer<Workspace>().future,
            ),
      ),
    );
    await pumpEventQueue();

    (web.document.querySelector('button[aria-label="Keyboard shortcuts"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);

    web.document.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'p',
          ctrlKey: !isMac,
          metaKey: isMac,
          shiftKey: true,
          bubbles: true,
          cancelable: true,
        ),
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.shortcuts-dialog'), isNull);
    expect(web.document.querySelector('.command-palette'), isNotNull);

    (web.document.querySelector('button[aria-label="Keyboard shortcuts"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(web.document.querySelector('.command-palette'), isNull);
    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);
  });
}
