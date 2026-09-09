// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';

final class _Workspace implements WorkspaceResourceApi {
  final MemoryWorkspaceResourceApi _delegate = MemoryWorkspaceResourceApi();
  int disposeCount = 0;

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => _delegate.changeEvents;

  @override
  Future<void> get changeEventsReady => _delegate.changeEventsReady;

  @override
  void addMoveIntention(String oldPath, String newPath) {
    _delegate.addMoveIntention(oldPath, newPath);
  }

  @override
  Future<void> createFolder(String uri) => _delegate.createFolder(uri);

  @override
  Future<void> deleteFileSystemEntity(String uri) => _delegate.deleteFileSystemEntity(uri);

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _delegate.dispose();
  }

  @override
  Future<bool> fileExist(String uri) => _delegate.fileExist(uri);

  @override
  Future<bool> folderExist(String uri) => _delegate.folderExist(uri);

  @override
  Future<List<({String path, String type})>> listDirectory({
    required String uri,
    bool recursive = false,
  }) => _delegate.listDirectory(uri: uri, recursive: recursive);

  @override
  Future<Uint8List> readFileAsBytes(String uri) => _delegate.readFileAsBytes(uri);

  @override
  Future<String> readFileAsText(String uri) => _delegate.readFileAsText(uri);

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) => _delegate.writeFileFromBytes(uri, bytes);

  @override
  Future<void> writeFileFromText(String uri, String content) => _delegate.writeFileFromText(uri, content);
}

void main() {
  test('creates workspace-scoped models and disposes them once', () async {
    final events = AppEventBus();
    final workspace = _Workspace();
    final repository = WorkspaceRepository(
      events: events,
      taskStatus: TaskStatusController(),
      workspaceResourceApi: workspace,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );
    final session = WorkspaceSession.create(repository);

    expect(session.repository, same(repository));
    expect(session.events, same(events));
    expect(session.taskStatus, same(repository.taskStatus));

    await session.dispose(closeWorker: false);
    await session.dispose(closeWorker: false);

    expect(workspace.disposeCount, 1);
    expect(
      () => session.taskStatus.startTask(TaskKind.startingAnalyzer),
      throwsStateError,
    );
    await expectLater(
      events.dispatchAsync(_TestEvent()),
      throwsA(isA<StateError>()),
    );
  });

  test('runOrHotReload calls runCode when preview canStart', () async {
    final events = AppEventBus();
    final workspace = _Workspace();
    final repository = WorkspaceRepository(
      events: events,
      taskStatus: TaskStatusController(),
      workspaceResourceApi: workspace,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );
    final session = WorkspaceSession.create(repository);

    expect(session.preview.canStart, isTrue);
    expect(session.preview.canHotReload, isFalse);

    // runOrHotReload starts runCode
    session.runOrHotReload();
    await Future<void>.delayed(Duration.zero);
    expect(session.preview.state, isA<PreviewStarting>());

    await session.dispose(closeWorker: false);
  });

  test('resolves runnable entrypoint based on main() presence', () async {
    final events = AppEventBus();
    final workspace = _Workspace();
    await workspace.writeFileFromText('lib/main.dart', 'void main() {}');
    await workspace.writeFileFromText('lib/other.dart', 'void other() {}');
    await workspace.writeFileFromText('lib/custom.dart', 'void main() {}');

    final repository = WorkspaceRepository(
      events: events,
      taskStatus: TaskStatusController(),
      workspaceResourceApi: workspace,
      sdk: defaultSdk,
      workspaceFuture: Completer<Workspace>().future,
    );
    final session = WorkspaceSession.create(repository);

    // canStart is immediately true without waiting on LSP
    expect(session.preview.canStart, isTrue);

    // 1. Custom file with main() becomes the runnable entrypoint
    final customEntrypoint = await session.resolveRunnableEntrypoint('lib/custom.dart');
    expect(customEntrypoint, 'lib/custom.dart');

    // 2. File without main() falls back to lib/main.dart
    final otherEntrypoint = await session.resolveRunnableEntrypoint('lib/other.dart');
    expect(otherEntrypoint, 'lib/main.dart');

    await session.dispose(closeWorker: false);
  });
}

final class _TestEvent extends AsyncEvent<String> {}
