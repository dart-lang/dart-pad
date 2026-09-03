// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/synced_workspace_resource_api.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';

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
  test('Pub Get logs its path and command output in order', () async {
    final events = AppEventBus();
    final logs = <LogEvent>[];
    final subscription = events.on<LogEvent>().listen(logs.add);
    String? commandPath;

    await runWorkspacePubGet(
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
      runWorkspacePubGet(
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

  group('workspace reset cleanup', () {
    test('disposes the workspace without disposing the worker', () async {
      final workspace = _Workspace();
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: workspace,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      await repository.closeWorkspaceOnly();

      expect(workspace.disposeCount, 1);
      expect(repository.dartpad, isNull);
    });

    test('propagates workspace cleanup failures', () async {
      final workspace = _Workspace()..disposeError = StateError('workspace already removed');
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: workspace,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      await expectLater(
        repository.closeWorkspaceOnly(),
        throwsA(isA<StateError>()),
      );
      expect(workspace.disposeCount, 1);
    });
  });

  group('hasFlutterDependency', () {
    test('reads package_config.json from the worker before it is mirrored locally', () async {
      final localApi = MemoryWorkspaceResourceApi();
      final remoteApi = MemoryWorkspaceResourceApi();
      await remoteApi.root.getFile('.dart_tool/package_config.json').writeContent('''
      {
        "configVersion": 2,
        "packages": [
          {
            "name": "flutter",
            "rootUri": "file:///path/to/flutter",
            "packageUri": "lib/",
            "languageVersion": "3.0"
          }
        ]
      }
      ''');
      final syncedApi = SyncedWorkspaceResourceApi(
        localApi: localApi,
        remoteApi: Future.value(remoteApi),
      );
      await syncedApi.apiReady;
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: syncedApi,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      expect(await localApi.fileExist('.dart_tool/package_config.json'), isFalse);
      expect(await repository.hasFlutterDependency('lib/main.dart'), isTrue);
    });

    test('returns true when flutter is a dependency in package_config.json', () async {
      final api = MemoryWorkspaceResourceApi();
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      final packageConfigContent = '''
      {
        "configVersion": 2,
        "packages": [
          {
            "name": "flutter",
            "rootUri": "file:///path/to/flutter",
            "packageUri": "lib/",
            "languageVersion": "3.0"
          }
        ]
      }
      ''';

      await api.root.getFile('.dart_tool/package_config.json').writeContent(packageConfigContent);

      final hasFlutter = await repository.hasFlutterDependency('lib/main.dart');
      expect(hasFlutter, isTrue);
    });

    test('returns false when package_config.json does not contain flutter dependency', () async {
      final api = MemoryWorkspaceResourceApi();
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      final packageConfigContent = '''
      {
        "configVersion": 2,
        "packages": [
          {
            "name": "path",
            "rootUri": "file:///path/to/path",
            "packageUri": "lib/",
            "languageVersion": "3.0"
          }
        ]
      }
      ''';

      await api.root.getFile('.dart_tool/package_config.json').writeContent(packageConfigContent);

      final hasFlutter = await repository.hasFlutterDependency('lib/main.dart');
      expect(hasFlutter, isFalse);
    });

    test('returns false when package_config.json is missing', () async {
      final api = MemoryWorkspaceResourceApi();
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      final hasFlutter = await repository.hasFlutterDependency('lib/main.dart');
      expect(hasFlutter, isFalse);
    });

    test('traverses up the directory tree to find package_config.json', () async {
      final api = MemoryWorkspaceResourceApi();
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      final packageConfigContent = '''
      {
        "configVersion": 2,
        "packages": [
          {
            "name": "flutter",
            "rootUri": "file:///path/to/flutter",
            "packageUri": "lib/",
            "languageVersion": "3.0"
          }
        ]
      }
      ''';

      await api.root.getFile('.dart_tool/package_config.json').writeContent(packageConfigContent);

      final hasFlutter = await repository.hasFlutterDependency('subproject/lib/src/helpers/util.dart');
      expect(hasFlutter, isTrue);
    });
  });

  group('convertToPackageUri', () {
    test('reads package_config.json from the worker before it is mirrored locally', () async {
      final localApi = MemoryWorkspaceResourceApi();
      final remoteApi = MemoryWorkspaceResourceApi();
      await remoteApi.root.getFile('example/.dart_tool/package_config.json').writeContent('''
      {
        "configVersion": 2,
        "packages": [
          {
            "name": "provider_example",
            "rootUri": "../",
            "packageUri": "lib/",
            "languageVersion": "3.0"
          }
        ]
      }
      ''');
      final syncedApi = SyncedWorkspaceResourceApi(
        localApi: localApi,
        remoteApi: Future.value(remoteApi),
      );
      await syncedApi.apiReady;
      final repository = WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: syncedApi,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
      );

      expect(await localApi.fileExist('example/.dart_tool/package_config.json'), isFalse);
      expect(
        await repository.convertToPackageUri('example/lib/main.dart'),
        Uri.parse('package:provider_example/main.dart'),
      );
    });
  });
}
