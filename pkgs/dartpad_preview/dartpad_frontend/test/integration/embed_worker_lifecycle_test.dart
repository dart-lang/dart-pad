// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Integration test using the bundled Flutter SDK, real workers and preview
// iframes: dart test test/integration/embed_worker_lifecycle_test.dart
@TestOn('browser')
@Timeout(Duration(minutes: 3))
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/codemirror/code_mirror_tab.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../project_fixture.dart';

int workerCount(String field) {
  final JSObject counts = web.window['embedWorkerCounts'];
  return (counts[field] as JSNumber).toDartInt;
}

void main() {
  setUpAll(() async {
    final script = web.HTMLScriptElement()..src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    web.document.head!.appendChild(script);
    await loaded;
    web.document.head!.appendChild(
      web.HTMLScriptElement()
        ..textContent = '''
          window.embedWorkerCounts = {created: 0, live: 0};
          const NativeWorker = window.Worker;
          window.Worker = class extends NativeWorker {
            constructor(...args) {
              super(...args);
              this.retired = false;
              embedWorkerCounts.created++;
              embedWorkerCounts.live++;
            }
            terminate() {
              if (!this.retired) { this.retired = true; embedWorkerCounts.live--; }
              super.terminate();
            }
          };
        ''',
    );
  });

  test('an idle embed starts on Run, releases its runtime on pause and resumes retained edits', () async {
    final sdk = SdkInfo(
      id: defaultSdk.id,
      name: defaultSdk.name,
      // Browser test URLs are rooted in test/integration/, assets in web/.
      path: '../../web/${defaultSdk.path}',
      dartVersion: defaultSdk.dartVersion,
      flutterVersion: defaultSdk.flutterVersion,
    );
    final contents = testProjectContents({
      'lib/main.dart': "import 'package:flutter/widgets.dart';\nvoid main() => runApp(const SizedBox());",
      'pubspec.yaml': 'name: embed_test\nenvironment:\n  sdk: ^3.10.0\ndependencies:\n  flutter:\n    sdk: flutter\n',
    });
    final initial = InitialProjectState.resolve(
      ProjectRequest.fromUri(Uri.parse('?embed=true&sdk=flutter')),
      contents,
      [sdk],
    );
    final local = MemoryWorkspaceResourceApi();
    await ProjectLoader.writeFiles(local.root, contents);
    final repository = WorkspaceRepository.create(
      events: AppEventBus(),
      taskStatus: TaskStatusController(),
      sdk: sdk,
      localApi: local,
      deferWorker: true,
    );
    late final WorkspaceSession session;
    session = WorkspaceSession.create(
      repository,
      initialProject: initial,
      initialMode: initial.mode,
      onBeforeRun: () async {
        if (repository.hasRuntime) {
          return;
        }
        print('Starting SDK worker');
        await session.tabs.saveAllTabs();
        final workspace = await repository.startWorker().timeout(const Duration(seconds: 45));
        print('Running pub get');
        await repository.pubGet().timeout(const Duration(seconds: 45));
        print('Starting analyzer');
        final server = await workspace.startLanguageServer().timeout(const Duration(seconds: 30));
        final client = LanguageServerClient(
          languageServer: server,
          rootWorkspaceUri: workspace.workspaceFolder,
          editorRootUri: workspace.workspaceFolder,
          workspaceChangeEvents: repository.workspaceResourceApi.changeEvents,
        );
        session.attachLanguageServer(server: server, client: client);
      },
    );
    addTearDown(() async {
      session.preview.containerElement.remove();
      await session.dispose();
      expect(workerCount('live'), 0);
    });
    await session.openProjectFiles();
    web.document.body!.appendChild(session.preview.containerElement);
    expect(workerCount('created'), 0);
    expect(repository.hasRuntime, isFalse);
    final workerScript = await web.window.fetch(sdk.assetBaseUrl.resolve('worker.js').toString().toJS).toDart;
    expect(workerScript.status, 200, reason: 'Missing SDK assets at ${sdk.assetBaseUrl}');

    await session.preview.runCurrent();
    expect(session.preview.state, isA<PreviewRunning>());
    expect(session.preview.containerElement.querySelector('iframe'), isNotNull);
    expect(session.fileTree.languageServerClient, isNotNull);
    expect(workerCount('live'), 1);
    final worker = repository.dartpad;
    final tab = session.tabs.getTab('lib/main.dart')! as WorkspaceCodeMirrorTab;
    final editor = tab.editor;
    final edited = '${tab.editor.text}\n// retained edit';
    tab.editor.text = edited;
    tab.editor.view.dispatch(cm.TransactionSpec(selection: cm.EditorSelection.single(7)));
    expect(tab.hasUnsavedChanges, isTrue);

    print('Pausing the runtime');
    await session.suspendRuntime(paused: true);
    expect(session.preview.state, isA<PreviewPaused>());
    expect(session.preview.canStart, isTrue);
    expect(session.preview.containerElement.querySelector('iframe'), isNull);
    expect(session.fileTree.languageServerClient, isNull);
    expect(repository.hasRuntime, isFalse);
    expect(repository.isClosed, isFalse);
    expect(workerCount('live'), 0);
    expect(tab.editor.text, edited);
    expect(tab.hasUnsavedChanges, isTrue);
    expect(tab.editor.view.state.selection.main.head, 7);
    tab.editor.text = '$edited\n// edited while paused';
    await repository.workspaceResourceApi.writeFileFromText('notes.txt', 'created while paused');

    print('Resuming the edited embed through Run');
    await session.preview.runCurrent();
    expect(session.preview.state, isA<PreviewRunning>());
    expect(session.preview.containerElement.querySelector('iframe'), isNotNull);
    expect(session.fileTree.languageServerClient, isNotNull);
    expect(session.tabs.getTab('lib/main.dart'), same(tab));
    expect(tab.editor, same(editor));
    expect(repository.dartpad, isNot(same(worker)));
    final workspace = await repository.readyWorkspace;
    expect(await workspace.readFileAsText('lib/main.dart'), contains('retained edit'));
    expect(await workspace.readFileAsText('lib/main.dart'), contains('edited while paused'));
    expect(await workspace.readFileAsText('notes.txt'), 'created while paused');
    expect(workerCount('created'), 2);
    expect(workerCount('live'), 1);
  });
}
