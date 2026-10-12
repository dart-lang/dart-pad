// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/view/preview_container.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/embed_runtime_controller.dart';
import 'package:jaspr/dom.dart' show div;
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

import '../../worker_fixture.dart';
import '../persistence/persistence_fixture.dart';

import 'initial_project_state_test.dart' show contents;

void main() {
  TestWorker.captureAssetBaseUrl();
  final startupWorkerAssets = Uri.base.resolve('../../fixtures/startup_worker/');
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
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          expect(sdk.isFlutter, isFalse);
          expect(deferWorker, isFalse);
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
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          created = true;
          throw StateError('Must not create a worker');
        },
      ),
    );
    await pumpEventQueue();
    expect(created, isFalse);
    expect(web.document.body!.textContent, contains('SDK not available: dart:0.0.0'));
  });

  for (final source in [
    '',
    'sample=counter',
    'sample=counter&run=true',
    'sample=counter&run=false',
    'sample_id=material.AppBar.1&run=true',
    'sample_id=material.AppBar.3&run=true',
    'sample_id=material.AppBar.1&run=false',
    'sample_id=material.AppBar.3&run=false',
    'sample_id=material.AppBar.1',
    'sample_id=material.AppBar.1&run=anything',
    'sample_id=material.AppBar.1&run=true&run=false',
    'gist=abc&run=true',
    'package=demo&run=true',
    'url=https://example.com/project.tar.gz&run=true',
  ]) {
    for (final embed in [false, true]) {
      testClient('preview autorun depends only on embed=$embed for $source', (tester) async {
        final worker = await DartPadSdk(assetBaseUrl: startupWorkerAssets).dedicatedWorker();
        addTearDown(worker.dispose);
        final workspace = await worker.createWorkspace();
        // Hold a started Run before it creates a sandbox or compiles code.
        final pendingRun = Completer<void>();
        tester.pumpComponent(
          App(
            projectStore: MemoryProjectStore(),
            initialUri: Uri.parse('/?embed=$embed&$source'),
            loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
            createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
                WorkspaceRepository(
                  events: events,
                  sdk: sdk,
                  taskStatus: taskStatus,
                  workspaceResourceApi: localApi!,
                  workspaceFuture: Future.value(workspace),
                  onFlush: () => pendingRun.future,
                ),
          ),
        );
        await pumpEventQueue();
        expect(web.document.querySelector('.cm-editor'), isNotNull);
        final container = find.byType(PreviewContainer).evaluate().single.component as PreviewContainer;
        expect(container.preview.state, embed ? isA<PreviewInitial>() : isA<PreviewStarting>());
        if (embed) {
          final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
          expect(run.disabled, isFalse);
          run.click();
          await pumpEventQueue();
          expect(container.preview.state, isA<PreviewStarting>());
        }
      });

      testClient('worker startup depends only on embed=$embed for $source', (tester) async {
        final starts = <Completer<DartPad>>[];
        tester.pumpComponent(
          App(
            projectStore: MemoryProjectStore(),
            initialUri: Uri.parse('/?embed=$embed&$source'),
            loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
            createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
              expect(deferWorker, embed);
              return WorkspaceRepository.create(
                events: events,
                sdk: sdk,
                taskStatus: taskStatus,
                localApi: localApi,
                deferWorker: deferWorker,
                createWorker: () {
                  final start = Completer<DartPad>();
                  starts.add(start);
                  return start.future;
                },
              );
            },
          ),
        );
        await pumpEventQueue();
        expect(web.document.querySelector('.cm-editor'), isNotNull);
        expect(starts, hasLength(embed ? 0 : 1));
        if (embed) {
          expect(web.document.querySelector('.preview iframe'), isNull);
          final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
          expect(run.disabled, isFalse);
          run.click();
          await pumpEventQueue();
          expect(starts, hasLength(1));
        }
      });
    }
  }

  for (final run in ['', '&run=false', '&run=true', '&run=anything', '&run=true&run=false']) {
    testClient('embed handshake injects without starting: $run', (tester) async {
      late WorkspaceRepository repository;
      final starts = <Completer<DartPad>>[];
      final originalName = web.window.name;
      web.window.name = 'flutter-docs-example';
      addTearDown(() => web.window.name = originalName);
      final readyMessages = <Object?>[];
      final subscription = web.EventStreamProviders.messageEvent.forTarget(web.window.parent).listen((event) {
        final data = event.data;
        if (data == null || !data.isA<JSObject>()) {
          return;
        }
        final message = data as JSObject;
        final type = message.getProperty<JSAny?>('type'.toJS)?.dartify();
        final sender = message.getProperty<JSAny?>('sender'.toJS)?.dartify();
        if (type == 'ready' && sender == web.window.name) {
          readyMessages.add({'type': type, 'sender': sender});
          injectSource("void main() { print('injected'); }");
        }
      });
      addTearDown(subscription.cancel);
      tester.pumpComponent(
        App(
          initialUri: Uri.parse('?embed=true&file=README.md$run'),
          loadSource: (_) async => contents({
            'README.md': '# Keep me',
            'lib/main.dart': 'void main() {}',
          }),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
            return repository = WorkspaceRepository.create(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              localApi: localApi,
              deferWorker: deferWorker,
              createWorker: () {
                final start = Completer<DartPad>();
                starts.add(start);
                return start.future;
              },
            );
          },
        ),
      );
      await pumpEventQueue();
      expect(readyMessages, [
        {'sender': 'flutter-docs-example', 'type': 'ready'},
      ]);
      expect(
        web.document.querySelector('.editor-tab-slot.active .cm-content')!.textContent,
        contains("print('injected')"),
      );
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('injected')"));
      expect(await repository.workspaceResourceApi.readFileAsText('README.md'), '# Keep me');
      expect(starts, isEmpty);

      injectSource("void main() { print('updated'); }");
      await pumpEventQueue();
      expect(
        web.document.querySelector('.editor-tab-slot.active .cm-content')!.textContent,
        contains("print('updated')"),
      );
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('updated')"));
      expect(starts, isEmpty);
      expect(repository.hasRuntime, isFalse);
      expect(web.document.querySelector('.app-footer'), isNull);
      expect(web.document.querySelector('.preview iframe'), isNull);
    });
  }

  testClient('early embed messages survive asynchronous project loading', (tester) async {
    final download = Completer<Project>();
    tester.pumpComponent(
      App(
        initialUri: Uri.parse('?embed=true'),
        loadSource: (_) => download.future,
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
            WorkspaceRepository.create(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              localApi: localApi,
              deferWorker: deferWorker,
              createWorker: () => Completer<DartPad>().future,
            ),
      ),
    );
    injectSource("void main() { print('early'); }");
    download.complete(contents({'lib/main.dart': 'void main() {}'}));
    await pumpEventQueue();
    expect(web.document.querySelector('.cm-content')!.textContent, contains("print('early')"));
  });

  testClient('seven protocol embeds stay idle and coordinate after manual activation', (tester) async {
    final repositories = List<WorkspaceRepository?>.filled(7, null);
    final starts = List<int>.filled(7, 0);
    tester.pumpComponent(
      div([
        for (var i = 0; i < 7; i++)
          div(classes: 'protocol-$i', [
            App(
              initialUri: Uri.parse('?run=true&embed=true'),
              loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
              createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
                expect(deferWorker, isTrue);
                return repositories[i] = WorkspaceRepository.create(
                  events: events,
                  sdk: sdk,
                  taskStatus: taskStatus,
                  localApi: localApi,
                  deferWorker: deferWorker,
                  createWorker: () {
                    starts[i]++;
                    return Completer<DartPad>().future;
                  },
                );
              },
            ),
          ]),
      ]),
    );
    await pumpEventQueue();
    expect(web.document.querySelectorAll('.cm-editor').length, 7);
    expect(starts, everyElement(0));
    injectSource("void main() { print('injected'); }");
    await pumpEventQueue();
    for (final repository in repositories) {
      expect(await repository!.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('injected')"));
      expect(repository.hasRuntime, isFalse);
    }
    expect(starts, everyElement(0));
    expect(web.document.querySelector('.preview iframe'), isNull);

    Future<void> notifyStorage() async {
      // These app instances share a test window. Real sibling iframes receive
      // this notification from the browser when another frame writes storage.
      web.window.dispatchEvent(
        web.StorageEvent('storage', web.StorageEventInit(storageArea: web.window.localStorage)),
      );
      await pumpEventQueue();
    }

    for (var i = 0; i < 3; i++) {
      (web.document.querySelector('.protocol-$i .main-editor-actions button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      await notifyStorage();
    }
    expect(starts, [1, 1, 1, 0, 0, 0, 0]);
    expect(repositories.map((repository) => repository!.hasRuntime), [false, true, true, false, false, false, false]);
    expect(web.document.querySelector('.protocol-0 button[aria-label="Resume"]'), isNotNull);

    injectSource("void main() { print('updated while paused'); }");
    await pumpEventQueue();
    expect(starts, [1, 1, 1, 0, 0, 0, 0]);
    expect(repositories.first!.hasRuntime, isFalse);
    expect(web.document.querySelector('.protocol-0 button[aria-label="Resume"]'), isNotNull);
    expect(
      await repositories.first!.workspaceResourceApi.readFileAsText('lib/main.dart'),
      contains('updated while paused'),
    );

    (web.document.querySelector('.protocol-0 button[aria-label="Resume"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
    await notifyStorage();
    expect(starts, [2, 1, 1, 0, 0, 0, 0]);
    expect(repositories.map((repository) => repository!.hasRuntime), [true, false, true, false, false, false, false]);
  });

  for (final query in ['', '?embed=false']) {
    testClient('without embed mode, protocol accepts code while the worker is starting: $query', (tester) async {
      final readyMessages = <Object?>[];
      final subscription = web.EventStreamProviders.messageEvent.forTarget(web.window.parent).listen((event) {
        final data = event.data;
        if (data == null || !data.isA<JSObject>()) {
          return;
        }
        final message = data as JSObject;
        final type = message.getProperty<JSAny?>('type'.toJS)?.dartify();
        final sender = message.getProperty<JSAny?>('sender'.toJS)?.dartify();
        if (type == 'ready' && sender == web.window.name) {
          readyMessages.add({'type': type, 'sender': sender});
          injectSource("void main() { print('injected'); }");
        }
      });
      addTearDown(subscription.cancel);
      late WorkspaceRepository repository;
      var starts = 0;
      tester.pumpComponent(
        App(
          initialUri: Uri.parse(query),
          projectStore: MemoryProjectStore(),
          loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
            expect(deferWorker, isFalse);
            return repository = WorkspaceRepository.create(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              localApi: localApi,
              deferWorker: deferWorker,
              createWorker: () {
                starts++;
                return Completer<DartPad>().future;
              },
            );
          },
        ),
      );
      await pumpEventQueue();
      expect(readyMessages, hasLength(1));
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('injected')"));
      expect(web.document.querySelector('.cm-content')!.textContent, contains("print('injected')"));

      injectSource("void main() { print('updated'); }");
      await pumpEventQueue();
      expect(readyMessages, hasLength(1));
      expect(starts, 1);
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('updated')"));
      expect(web.document.querySelector('.cm-content')!.textContent, contains("print('updated')"));
      expect(web.document.querySelector('.app-footer'), isNotNull);
    });
  }

  testClient('embed Run lazily starts the runtime and can resume while retired startup is pending', (tester) async {
    late WorkspaceRepository repository;
    final starts = <Completer<DartPad>>[];
    tester.pumpComponent(
      App(
        initialUri: Uri.parse('/?sample_id=material.ListTile.3&run=false&embed=true'),
        loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          expect(deferWorker, isTrue);
          return repository = WorkspaceRepository.create(
            events: events,
            sdk: sdk,
            taskStatus: taskStatus,
            localApi: localApi,
            deferWorker: deferWorker,
            createWorker: () {
              final start = Completer<DartPad>();
              starts.add(start);
              return start.future;
            },
          );
        },
      ),
    );
    await pumpEventQueue();
    expect(starts, isEmpty);
    final editor = web.document.querySelector('.cm-editor');
    expect(editor, isNotNull);
    final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
    run.click();
    await pumpEventQueue();
    expect(starts, hasLength(1));
    expect(repository.hasRuntime, isTrue);
    expect(web.document.querySelector('.cm-editor'), equals(editor));
    expect(run.disabled, isTrue);
    final firstKey = '${EmbedRuntimeController.storageKeyPrefix}other-a';
    final secondKey = '${EmbedRuntimeController.storageKeyPrefix}other-b';
    final timestamp = DateTime.now().millisecondsSinceEpoch + 100;
    web.window.localStorage.setItem(firstKey, jsonEncode({'lastSeen': timestamp}));
    web.window.localStorage.setItem(secondKey, jsonEncode({'lastSeen': timestamp + 1}));
    addTearDown(() {
      web.window.localStorage.removeItem(firstKey);
      web.window.localStorage.removeItem(secondKey);
    });
    web.window.dispatchEvent(
      web.StorageEvent(
        'storage',
        web.StorageEventInit(
          key: secondKey,
          storageArea: web.window.localStorage,
        ),
      ),
    );
    await pumpEventQueue();
    expect(repository.hasRuntime, isFalse);
    expect(web.document.querySelector('.cm-editor'), equals(editor));
    expect(run.disabled, isFalse);
    expect(web.document.body!.textContent, contains('LSP and Preview paused'));
    final resume = web.document.querySelector('button[aria-label="Resume"]')! as web.HTMLButtonElement;
    expect(resume.disabled, isFalse);
    resume.click();
    await pumpEventQueue();
    expect(starts, hasLength(2));
    expect(web.document.querySelector('button[aria-label="Resume"]'), isNull);
    starts.first.completeError(StateError('Retired startup failed'));
    await pumpEventQueue();
    expect(repository.hasRuntime, isTrue);
    expect(web.document.body!.textContent, isNot(contains('Retired startup failed')));
    expect(run.disabled, isTrue);
  });

  for (final source in ['sample=counter', 'sample_id=material.AppBar.1&channel=stable']) {
    for (final split in [5, 60, 95]) {
      testClient('embed layout and split=$split are source-independent for $source', (tester) async {
        tester.pumpComponent(
          App(
            projectStore: MemoryProjectStore(),
            initialUri: Uri.parse('/?$source&split=$split&embed=true'),
            loadSource: (_) async => contents({
              'lib/main.dart': "import 'package:flutter/material.dart'; void main() {}",
              'pubspec.yaml': 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n',
            }),
            createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
              expect(sdk.isFlutter, isTrue);
              expect(deferWorker, isTrue);
              return WorkspaceRepository(
                events: events,
                taskStatus: taskStatus,
                sdk: sdk,
                workspaceResourceApi: localApi!,
              );
            },
          ),
        );
        await pumpEventQueue();

        expect(web.document.querySelector('.app-bar'), isNull);
        expect(web.document.querySelector('.app-footer'), isNull);
        expect(web.document.querySelector('.file-tree-rail'), isNotNull);
        final editorShell = web.document.querySelector('.editor-shell')! as web.HTMLElement;
        expect(editorShell.style.flexGrow, (split / 100).toString());
      });
    }
  }

  for (final hasMain in [true, false]) {
    testClient('missing README opens main when available, hasMain=$hasMain', (tester) async {
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=counter'),
          loadSource: (_) async => contents({if (hasMain) 'lib/main.dart': 'void main() {}'}),
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
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
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
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
            old = WorkspaceRepository(
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

void injectSource(String source) {
  web.window.dispatchEvent(
    web.MessageEvent(
      'message',
      web.MessageEventInit(
        source: web.window.parent,
        origin: 'https://docs.flutter.dev',
        data: {'type': 'sourceCode', 'sourceCode': source}.jsify(),
      ),
    ),
  );
}
