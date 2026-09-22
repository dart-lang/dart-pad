// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/synced_workspace_resource_api.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';

import '../../worker_fixture.dart';

final class _Workspace implements WorkspaceResourceApi {
  final Set<String> folders = {''};
  final List<String> deletedPaths = [];
  Error? disposeError;
  int disposeCount = 0;

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => const Stream.empty();

  @override
  Future<void> get changeEventsReady => Future.value();

  @override
  Future<bool> folderExist(String uri) async => folders.contains(uri);

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    deletedPaths.add(uri);
    folders.removeWhere((path) => path == uri || path.startsWith('$uri/'));
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (disposeError case final error?) {
      throw error;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWorker.captureAssetBaseUrl();
  test('Pub Get logs its path and command output in order', () async {
    final events = AppEventBus();
    final logs = <LogEvent>[];
    final subscription = events.on<LogEvent>().listen(logs.add);
    String? commandPath;

    await runWorkspacePubCommand(
      commandName: 'get',
      events: events,
      path: 'example/.',
      projectRoot: 'example',
      command: (path) async {
        commandPath = path;
        return 'Resolving dependencies...';
      },
    );
    await pumpEventQueue();

    expect(commandPath, 'example');
    expect(logs.map((event) => event.message), [
      'Running pub get in /',
      'Resolving dependencies...',
    ]);

    await subscription.cancel();
    await events.dispose();
  });

  test('Pub Get propagates command failures after logging its path', () async {
    final events = AppEventBus();
    final logs = <LogEvent>[];
    final subscription = events.on<LogEvent>().listen(logs.add);
    final failure = StateError('pub failed');

    await expectLater(
      runWorkspacePubCommand(
        commandName: 'get',
        events: events,
        path: '',
        projectRoot: '',
        command: (_) async => throw failure,
      ),
      throwsA(same(failure)),
    );
    await pumpEventQueue();

    expect(logs.map((event) => event.message), ['Running pub get in /']);

    await subscription.cancel();
    await events.dispose();
  });

  test('runWorkspacePubCommand logs its path and command output in order', () async {
    final events = AppEventBus();
    final logs = <LogEvent>[];
    final subscription = events.on<LogEvent>().listen(logs.add);
    String? commandPath;

    await runWorkspacePubCommand(
      events: events,
      commandName: 'upgrade',
      path: 'example/.',
      projectRoot: 'example',
      command: (path) async {
        commandPath = path;
        return 'Upgraded dependencies...';
      },
    );
    await pumpEventQueue();

    expect(commandPath, 'example');
    expect(logs.map((event) => event.message), [
      'Running pub upgrade in /',
      'Upgraded dependencies...',
    ]);

    await subscription.cancel();
    await events.dispose();
  });

  for (final testCase in [
    (name: 'workspace root', path: '', projectRoot: '', expected: '/'),
    (name: 'project root', path: 'example', projectRoot: 'example', expected: '/'),
    (
      name: 'project descendant',
      path: 'packages/demo/example',
      projectRoot: 'packages/demo',
      expected: 'example',
    ),
    (name: 'above project root', path: '', projectRoot: 'example', expected: '..'),
  ]) {
    test('runWorkspacePubCommand displays ${testCase.name}', () async {
      final events = AppEventBus();
      final logs = <LogEvent>[];
      final subscription = events.on<LogEvent>().listen(logs.add);

      await runWorkspacePubCommand(
        events: events,
        commandName: 'get',
        path: testCase.path,
        projectRoot: testCase.projectRoot,
        command: (_) async => '',
      );
      await pumpEventQueue();

      expect(logs.map((event) => event.message), ['Running pub get in ${testCase.expected}']);

      await subscription.cancel();
      await events.dispose();
    });
  }

  test(
    'cleanGeneratedOutput removes build and .dart_tool when present',
    () async {
      final workspace = _Workspace()..folders.addAll({'build', 'build/web', '.dart_tool'});

      await WorkspaceRepository.cleanGeneratedOutput(workspace);

      expect(workspace.deletedPaths, ['build', '.dart_tool']);
      expect(workspace.folders, {''});
    },
  );

  test(
    'cleanGeneratedOutput is a no-op when generated folders are absent',
    () async {
      final workspace = _Workspace();

      await WorkspaceRepository.cleanGeneratedOutput(workspace);

      expect(workspace.deletedPaths, isEmpty);
    },
  );

  test(
    'cleanGeneratedOutput removes output below the active project path',
    () async {
      final workspace = _Workspace()
        ..folders.addAll({
          'examples/counter/build',
          'examples/counter/.dart_tool',
          'build',
          '.dart_tool',
        });

      await WorkspaceRepository.cleanGeneratedOutput(
        workspace,
        path: 'examples/counter',
      );

      expect(workspace.deletedPaths, [
        'examples/counter/build',
        'examples/counter/.dart_tool',
      ]);
      expect(workspace.folders, containsAll({'build', '.dart_tool'}));
    },
  );

  test('Pub Clean exposes a blocking task status', () async {
    final workspace = _Workspace()..folders.add('example/build');
    final taskStatus = TaskStatusController();
    final repository = WorkspaceRepository(
      events: AppEventBus(),
      taskStatus: taskStatus,
      workspaceResourceApi: workspace,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );

    final future = repository.pubClean(path: 'example');
    expect(taskStatus.current?.kind, TaskKind.pubClean);
    expect(taskStatus.current?.label, 'Pub clean in example');
    expect(taskStatus.current?.scope, 'example');
    expect(taskStatus.hasBlockingPreviewTask, isTrue);
    await future;

    expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);
    expect(taskStatus.hasBlockingPreviewTask, isFalse);
    taskStatus.dispose();
    await repository.events.dispose();
  });

  test('Pub Upgrade exposes a blocking task status', () async {
    final completer = Completer<Workspace>();
    final taskStatus = TaskStatusController();
    final repository = WorkspaceRepository(
      events: AppEventBus(),
      taskStatus: taskStatus,
      workspaceResourceApi: _Workspace(),
      sdk: defaultSdk,
      workspaceFuture: completer.future,
    );

    final future = repository.pubUpgrade(path: 'example');
    expect(taskStatus.current?.kind, TaskKind.pubUpgrade);
    expect(taskStatus.current?.label, 'Pub upgrade in example');
    expect(taskStatus.current?.scope, 'example');
    expect(taskStatus.hasBlockingPreviewTask, isTrue);

    completer.completeError(StateError('workspace not available'));
    await expectLater(future, throwsA(isA<StateError>()));

    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);
    expect(taskStatus.hasBlockingPreviewTask, isFalse);
    taskStatus.dispose();
    await repository.events.dispose();
  });

  test('Pub Downgrade exposes a blocking task status', () async {
    final completer = Completer<Workspace>();
    final taskStatus = TaskStatusController();
    final repository = WorkspaceRepository(
      events: AppEventBus(),
      taskStatus: taskStatus,
      workspaceResourceApi: _Workspace(),
      sdk: defaultSdk,
      workspaceFuture: completer.future,
    );

    final future = repository.pubDowngrade(path: 'example');
    expect(taskStatus.current?.kind, TaskKind.pubDowngrade);
    expect(taskStatus.current?.label, 'Pub downgrade in example');
    expect(taskStatus.current?.scope, 'example');
    expect(taskStatus.hasBlockingPreviewTask, isTrue);

    completer.completeError(StateError('workspace not available'));
    await expectLater(future, throwsA(isA<StateError>()));

    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);
    expect(taskStatus.hasBlockingPreviewTask, isFalse);
    taskStatus.dispose();
    await repository.events.dispose();
  });

  test('Pub Outdated exposes a non-blocking task status', () async {
    final completer = Completer<Workspace>();
    final taskStatus = TaskStatusController();
    final repository = WorkspaceRepository(
      events: AppEventBus(),
      taskStatus: taskStatus,
      workspaceResourceApi: _Workspace(),
      sdk: defaultSdk,
      workspaceFuture: completer.future,
    );

    final future = repository.pubOutdated(path: 'example');
    expect(taskStatus.current?.kind, TaskKind.pubOutdated);
    expect(taskStatus.current?.label, 'Pub outdated in example');
    expect(taskStatus.current?.scope, 'example');
    expect(taskStatus.hasBlockingPreviewTask, isFalse);

    completer.completeError(StateError('workspace not available'));
    await expectLater(future, throwsA(isA<StateError>()));

    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);
    expect(taskStatus.hasBlockingPreviewTask, isFalse);
    taskStatus.dispose();
    await repository.events.dispose();
  });

  group('worker cleanup', () {
    test('retains an early startup error for a later readiness await without an uncaught error', () async {
      final events = AppEventBus();
      final tasks = TaskStatusController();
      final workerReady = Completer<DartPad>();
      final failure = StateError('Worker startup failed');
      final repository = WorkspaceRepository.create(
        events: events,
        taskStatus: tasks,
        sdk: defaultSdk,
        createWorker: () => workerReady.future,
      );
      addTearDown(repository.close);
      addTearDown(events.dispose);
      addTearDown(tasks.dispose);

      workerReady.completeError(failure);
      await pumpEventQueue();

      await expectLater(repository.readyWorkspace, throwsA(same(failure)));
    });

    for (final cleanupFails in [false, true]) {
      test('closes the workspace and worker once, workspace cleanup fails=$cleanupFails', () async {
        final workspace = _Workspace();
        final failure = StateError('workspace already removed');
        if (cleanupFails) {
          workspace.disposeError = failure;
        }
        final worker = await TestWorker.start();
        addTearDown(worker.dispose);
        final events = AppEventBus();
        final tasks = TaskStatusController();
        addTearDown(events.dispose);
        addTearDown(tasks.dispose);
        final repository = WorkspaceRepository.create(
          events: events,
          taskStatus: tasks,
          sdk: defaultSdk,
          localApi: workspace,
          createWorker: () async => worker.dartpad,
        );
        await expectLater(repository.readyWorkspace, throwsA(isA<Exception>()));
        expect(repository.dartpad, same(worker.dartpad));

        final closed = repository.close();
        expect(repository.close(), same(closed));
        if (cleanupFails) {
          await expectLater(closed, throwsA(same(failure)));
        } else {
          await closed;
        }
        expect(workspace.disposeCount, 1);
        expect(worker.isClosed, isTrue);
      });
    }

    for (final observeReadiness in [true, false]) {
      test('disposes a late worker after closing, readiness observed=$observeReadiness', () async {
        final workerReady = Completer<DartPad>();
        final worker = await TestWorker.start();
        addTearDown(worker.dispose);
        final events = AppEventBus();
        final tasks = TaskStatusController();
        final repository = WorkspaceRepository.create(
          events: events,
          taskStatus: tasks,
          sdk: defaultSdk,
          createWorker: () => workerReady.future,
        );
        final ready = observeReadiness
            ? expectLater(
                repository.readyWorkspace,
                throwsA(
                  isA<StateError>().having(
                    (error) => error.message,
                    'message',
                    contains('closed during worker initialization'),
                  ),
                ),
              )
            : null;

        await repository.close();
        await events.dispose();
        tasks.dispose();
        expect(worker.isClosed, isFalse);

        workerReady.complete(worker.dartpad);
        await worker.dartpad.done;
        await ready;
        await pumpEventQueue();
        await repository.close();
        expect(repository.dartpad, isNull);
        expect(worker.isClosed, isTrue);
      });
    }
  });

  test('run mode uses nearest pubspec and path with the selected SDK', () async {
    final api = MemoryWorkspaceResourceApi();
    final events = AppEventBus();
    final tasks = TaskStatusController();
    final repository = WorkspaceRepository(
      events: events,
      taskStatus: tasks,
      workspaceResourceApi: api,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );
    await api.writeFileFromText('example/pubspec.yaml', 'name: example');
    expect(await repository.runModeFor('example/tool/check.dart'), RunMode.console);
    expect(await repository.runModeFor('example/lib/main.dart'), RunMode.flutter);
    expect(await repository.runModeFor('example/test/check.dart'), RunMode.console);
    await repository.close();
    await events.dispose();
    tasks.dispose();
  });

  test('SDK workspace copy preserves edited text and binary bytes independently', () async {
    final api = MemoryWorkspaceResourceApi();
    final events = AppEventBus();
    final tasks = TaskStatusController();
    final repository = WorkspaceRepository(
      events: events,
      taskStatus: tasks,
      workspaceResourceApi: api,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );
    await api.writeFileFromText('example/lib/main.dart', 'void main() { print(42); }');
    await api.writeFileFromBytes('assets/image.png', Uint8List.fromList([0, 255, 42]));
    final copy = await repository.copyFiles();
    await api.writeFileFromText('example/lib/main.dart', 'changed again');
    await repository.close();
    expect(await copy.readFileAsText('example/lib/main.dart'), 'void main() { print(42); }');
    expect(await copy.readFileAsBytes('assets/image.png'), [0, 255, 42]);
    await copy.dispose();
    await events.dispose();
    tasks.dispose();
  });

  test('flush propagates pending local writes to the worker', () async {
    final local = MemoryWorkspaceResourceApi();
    final remote = MemoryWorkspaceResourceApi();
    final api = SyncedWorkspaceResourceApi(localApi: local, remoteApi: Future.value(remote));
    await api.apiReady;
    final events = AppEventBus();
    final tasks = TaskStatusController();
    final repository = WorkspaceRepository(
      events: events,
      taskStatus: tasks,
      workspaceResourceApi: api,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );
    await api.writeFileFromText('main.dart', 'void main() {}');
    await repository.flush();
    expect(await remote.readFileAsText('main.dart'), 'void main() {}');
    await api.dispose();
    tasks.dispose();
    await events.dispose();
  });
}
