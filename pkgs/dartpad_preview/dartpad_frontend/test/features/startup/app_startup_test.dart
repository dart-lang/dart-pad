// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

import '../../worker_fixture.dart';
import '../persistence/persistence_fixture.dart';

import 'initial_project_state_test.dart' show contents;

void main() {
  TestWorker.captureAssetBaseUrl();
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  testClient('waits for project resolution before creating the correct SDK worker and opens initial tabs', (
    tester,
  ) async {
    final download = Completer<Project>();
    WorkspaceRepository? created;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?file=README.md&file=lib/main.dart'),
        loadSource: (_) => download.future,
        createRepository: ({required events, required sdk, required taskStatus, localApi}) {
          expect(sdk.isFlutter, isFalse);
          return created = WorkspaceRepository(
            events: events,
            taskStatus: taskStatus,
            sdk: sdk,
            workspaceResourceApi: localApi!,
            workspaceFuture: Completer<Workspace>().future,
          );
        },
      ),
    );
    await pumpEventQueue();
    expect(created, isNull);
    expect(web.document.querySelector('.editor-shell .editor-area'), isNotNull);
    expect(web.document.querySelector('.editor-tab-bar'), isNotNull);
    expect(web.document.body!.textContent, isNot(contains('Loading project')));
    expect(web.document.querySelector('.app-shell > .task-status-anchor'), isNull);
    expect(web.document.querySelector('.app-footer .task-status-trigger'), isNotNull);
    download.complete(
      contents({'README.md': '# Project', 'lib/main.dart': 'void main() {}', 'pubspec.yaml': 'name: demo'}),
    );
    await pumpEventQueue();
    expect(created, isNotNull);
    expect(await created!.workspaceResourceApi.fileExist('lib/main.dart'), isTrue);
    final tabs = web.document.querySelectorAll('.editor-tab-name');
    expect([for (var i = 0; i < tabs.length; i++) tabs.item(i)!.textContent], ['README.md', 'main.dart']);
    expect(web.document.querySelector('.editor-tab.active')!.textContent, contains('README.md'));
    expect(web.document.querySelector('.app-shell > .task-status-anchor'), isNull);
    expect(web.document.querySelector('.app-footer .task-status-trigger'), isNotNull);
  });

  testClient('invalid SDK version shows an actionable error without starting a worker', (tester) async {
    var created = false;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?sdk=dart:0.0.0'),
        loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
        createRepository: ({required events, required sdk, required taskStatus, localApi}) {
          created = true;
          throw StateError('Must not create a worker');
        },
      ),
    );
    await pumpEventQueue();
    expect(created, isFalse);
    expect(web.document.body!.textContent, contains('SDK not available: dart:0.0.0'));
  });

  testClient('legacy Flutter API URLs use the preview embed layout and requested split', (tester) async {
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse(
          '/?sample_id=material.AppBar.1&channel=stable&split=60&run=false&embed=true',
        ),
        loadSource: (source) async {
          expect(source, isA<FlutterApiDocsProjectSource>());
          return contents({
            'lib/main.dart': "import 'package:flutter/material.dart'; void main() {}",
          });
        },
        createRepository: ({required events, required sdk, required taskStatus, localApi}) {
          expect(sdk.isFlutter, isTrue);
          return WorkspaceRepository(
            events: events,
            taskStatus: taskStatus,
            sdk: sdk,
            workspaceResourceApi: localApi!,
            workspaceFuture: Completer<Workspace>().future,
          );
        },
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.app-bar'), isNull);
    expect(web.document.querySelector('.app-footer'), isNull);
    expect(web.document.querySelector('.file-tree-rail'), isNotNull);
    final editorShell = web.document.querySelector('.editor-shell')! as web.HTMLElement;
    expect(editorShell.style.flexGrow, '0.6');
  });

  for (final hasMain in [true, false]) {
    testClient('missing README opens main when available, hasMain=$hasMain', (tester) async {
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=counter'),
          loadSource: (_) async => contents({if (hasMain) 'lib/main.dart': 'void main() {}'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi}) => WorkspaceRepository(
            events: events,
            sdk: sdk,
            taskStatus: taskStatus,
            workspaceResourceApi: localApi!,
            workspaceFuture: Completer<Workspace>().future,
          ),
        ),
      );
      await pumpEventQueue();
      if (hasMain) {
        expect(web.document.querySelectorAll('.editor-tab').length, 1);
        expect(web.document.querySelector('.editor-tab.active .editor-tab-name')?.textContent, 'main.dart');
      } else {
        expect(web.document.querySelector('.editor-tab'), isNull);
      }
    });
  }

  for (final embed in [false, true]) {
    testClient('project load failures show an error dialog with recovery, embed=$embed', (tester) async {
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=counter&embed=$embed'),
          loadSource: (_) async => throw const FormatException('Project download failed'),
        ),
      );
      await pumpEventQueue();
      expect(web.document.querySelector('[role="alertdialog"]')?.textContent, contains('Project download failed'));
      expect(web.document.querySelector('button[aria-label="Reload Page"]'), isNotNull);
      if (embed) {
        expect(web.document.querySelector('.app-bar'), isNull);
      }
      expect(web.document.querySelector('.editor-tab'), isNull);
    });
  }

  for (final initialSample in ['fibonacci', 'dart']) {
    testClient('opening Dart Snippet from $initialSample creates a fresh same-SDK worker', (tester) async {
      final originalUrl = web.window.location.href;
      addTearDown(() => web.window.history.replaceState(null, '', originalUrl));
      final repositories = <WorkspaceRepository>[];
      final workers = [await TestWorker.start(), await TestWorker.start()];
      for (final worker in workers) {
        addTearDown(worker.dispose);
      }
      var loads = 0;
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=$initialSample'),
          loadSource: (_) async => contents({'lib/main.dart': 'void main() { print(${++loads}); }'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi}) {
            final repository = WorkspaceRepository(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              workspaceResourceApi: localApi!,
              dartpad: workers[repositories.length].dartpad,
              workspaceFuture: Completer<Workspace>().future,
              readyWorkspaceFuture: Future.error(StateError('Test worker unavailable')),
            );
            repositories.add(repository);
            return repository;
          },
        ),
      );
      await pumpEventQueue();
      final old = repositories.single;
      expect(workers.first.isClosed, isFalse);
      (web.document.querySelector('button[aria-label="New"]')! as web.HTMLElement).click();
      await pumpEventQueue();
      final items = web.document.querySelectorAll('.dropdown-menu-item');
      final snippet = [
        for (var i = 0; i < items.length; i++) items.item(i)!,
      ].singleWhere((item) => item.textContent!.contains('Dart Snippet'));
      (snippet as web.HTMLElement).click();
      await pumpEventQueue();

      expect(loads, 2);
      expect(repositories, hasLength(2));
      final next = repositories.last;
      expect(next.sdk, old.sdk);
      expect(next.dartpad, isNot(same(old.dartpad)));
      expect(old.closeCount, 1);
      expect(workers.first.isClosed, isTrue);
      expect(next.closeCount, 0);
      expect(web.document.querySelector('.cm-content')!.textContent, contains('print(2)'));

      tester.binding.detachRootComponent();
      await pumpEventQueue();
      expect(old.closeCount, 1);
      expect(next.closeCount, 1);
      expect(workers.last.isClosed, isTrue);
    });
  }

  testClient('failed sample reset removes and disposes the old session', (tester) async {
    final originalUrl = web.window.location.href;
    addTearDown(() => web.window.history.replaceState(null, '', originalUrl));
    late WorkspaceRepository old;
    final worker = await TestWorker.start();
    addTearDown(worker.dispose);
    var loads = 0;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?file=README.md'),
        loadSource: (_) async {
          if (++loads > 1) {
            throw const FormatException('New sample failed');
          }
          return contents({'README.md': '# Original project'});
        },
        createRepository: ({required events, required sdk, required taskStatus, localApi}) => old = WorkspaceRepository(
          events: events,
          sdk: sdk,
          taskStatus: taskStatus,
          workspaceResourceApi: localApi!,
          dartpad: worker.dartpad,
          workspaceFuture: Completer<Workspace>().future,
          readyWorkspaceFuture: Future.error(StateError('Test worker unavailable')),
        ),
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.editor-tab'), isNotNull);
    (web.document.querySelector('button[aria-label="New"]')! as web.HTMLElement).click();
    await pumpEventQueue();
    (web.document.querySelector('.dropdown-menu-item')! as web.HTMLElement).click();
    await pumpEventQueue();
    expect(loads, 2);
    expect(web.window.location.search, contains('sample='));
    expect(web.document.querySelector('.editor-tab'), isNull);
    expect(web.document.querySelector('[role="alertdialog"]')?.textContent, contains('New sample failed'));
    expect(old.closeCount, 1);
    expect(worker.isClosed, isTrue);
    expect(() => old.taskStatus.startTask(TaskKind.loadingCode), throwsStateError);
  });
}
