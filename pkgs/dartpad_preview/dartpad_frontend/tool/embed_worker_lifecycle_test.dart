// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Opt-in integration test using the bundled Flutter SDK, real workers and
// preview iframes: dart test tool/embed_worker_lifecycle_test.dart
@TestOn('browser')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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
import 'package:dartpad_frontend/features/workspace/embed_runtime_controller.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../test/project_fixture.dart';

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

  test('seven idle editors start no workers; N=2 retires the oldest and resumes retained edits', () async {
    final sdk = SdkInfo(
      id: defaultSdk.id,
      name: defaultSdk.name,
      path: '../web/${defaultSdk.path}',
      dartVersion: defaultSdk.dartVersion,
      flutterVersion: defaultSdk.flutterVersion,
    );
    final sessions = <WorkspaceSession>[];
    final controllers = <EmbedRuntimeController>[];
    final frames = <web.HTMLIFrameElement>[];
    final suspensions = <WorkspaceSession, Future<void>>{};
    addTearDown(() async {
      for (final controller in controllers) {
        controller.dispose();
      }
      await Future.wait(suspensions.values);
      for (final session in sessions) {
        session.preview.containerElement.remove();
        await session.dispose();
      }
      for (final frame in frames) {
        frame.remove();
      }
      expect(workerCount('live'), 0);
    });
    for (var i = 0; i < 7; i++) {
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
      final session = WorkspaceSession.create(repository, initialProject: initial, initialMode: initial.mode);
      sessions.add(session);
      final frame = web.HTMLIFrameElement()..srcdoc = '<!doctype html><body></body>'.toJS;
      frames.add(frame);
      final loaded = web.EventStreamProviders.loadEvent.forTarget(frame).first;
      web.document.body!.appendChild(frame);
      await loaded;
      controllers.add(
        EmbedRuntimeController(
          window: frame.contentWindow,
          onPause: () => suspensions[session] = session.suspendRuntime(paused: true),
        ),
      );
      await session.openProjectFiles();
      web.document.body!.appendChild(session.preview.containerElement);
    }
    expect(workerCount('created'), 0);
    final workerScript = await web.window.fetch(sdk.assetBaseUrl.resolve('worker.js').toString().toJS).toDart;
    expect(workerScript.status, 200, reason: 'Missing SDK assets at ${sdk.assetBaseUrl}');

    Future<void> start(WorkspaceSession session) async {
      controllers[sessions.indexOf(session)].activate();
      print('Starting SDK worker');
      await session.tabs.saveAllTabs();
      final workspace = await session.repository.startWorker().timeout(const Duration(seconds: 45));
      print('Running pub get');
      await session.repository.pubGet().timeout(const Duration(seconds: 45));
      print('Starting analyzer');
      final server = await workspace.startLanguageServer().timeout(const Duration(seconds: 30));
      final client = LanguageServerClient(
        languageServer: server,
        rootWorkspaceUri: workspace.workspaceFolder,
        editorRootUri: workspace.workspaceFolder,
        workspaceChangeEvents: session.repository.workspaceResourceApi.changeEvents,
      );
      session.attachLanguageServer(server: server, client: client);
      print('Compiling Flutter preview');
      await session.preview.runCurrent().timeout(const Duration(seconds: 45));
      expect(session.preview.state, isA<PreviewRunning>());
      expect(session.preview.containerElement.querySelector('iframe'), isNotNull);
    }

    final first = sessions[0];
    final second = sessions[1];
    final third = sessions[2];
    await start(first);
    expect(workerCount('live'), 1);
    final tab = first.tabs.getTab('lib/main.dart')! as WorkspaceCodeMirrorTab;
    final edited = '${tab.editor.text}\n// retained edit';
    tab.editor.text = edited;
    print('Starting a second embed alongside the first');
    await start(second);
    expect(first.preview.state, isA<PreviewRunning>());
    expect(workerCount('live'), 2);
    print('Starting a third embed and retiring the oldest');
    await start(third);
    await suspensions[first];
    expect(first.preview.state, isA<PreviewPaused>());
    expect(first.preview.containerElement.querySelector('iframe'), isNull);
    expect(second.preview.state, isA<PreviewRunning>());
    expect(workerCount('live'), 2);
    expect(tab.editor.text, edited);

    print('Switching back to edited embed');
    await start(first);
    await suspensions[second];
    expect(second.preview.state, isA<PreviewPaused>());
    expect(third.preview.state, isA<PreviewRunning>());
    expect(first.tabs.getTab('lib/main.dart'), same(tab));
    expect(await (await first.repository.readyWorkspace).readFileAsText('lib/main.dart'), contains('retained edit'));
    expect(workerCount('created'), 4);
    expect(workerCount('live'), 2);
  });
}
