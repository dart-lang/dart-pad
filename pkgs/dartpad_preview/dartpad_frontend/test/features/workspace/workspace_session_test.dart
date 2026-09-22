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
import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/components/command_palette_actions.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../project_fixture.dart';

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
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

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
    final initial = testProject();
    final session = WorkspaceSession.create(repository, initialProject: initial, initialMode: initial.mode);

    expect(session.repository, same(repository));
    expect(session.events, same(events));
    expect(session.taskStatus, same(repository.taskStatus));

    await session.dispose();
    await session.dispose();

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
    final initial = testProject();
    final session = WorkspaceSession.create(repository, initialProject: initial, initialMode: initial.mode);

    expect(session.preview.canStart, isTrue);
    expect(session.preview.canHotReload, isFalse);

    // runOrHotReload starts runCode
    session.runOrHotReload();
    expect(session.preview.state, isA<PreviewStarting>());

    await session.dispose();
  });

  test('initial tabs open in order and tab changes leave the entrypoint and initial metadata intact', () async {
    final contents = testProjectContents({
      'README.md': '# Project',
      'pubspec.yaml': 'name: demo',
      'lib/main.dart': 'void main() {}',
      'other.dart': 'void main() {}',
    });
    final initial = InitialProjectState.resolve(
      ProjectRequest.fromUri(Uri.parse('?file=README.md&file=lib/main.dart')),
      contents,
      availableSdks,
    );
    final api = _Workspace();
    await ProjectLoader.writeFiles(api.root, contents);
    final session = WorkspaceSession.create(
      WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: initial.sdk,
        workspaceFuture: Completer<Workspace>().future,
      ),
      initialProject: initial,
      initialMode: initial.mode,
    );
    try {
      await session.openProjectFiles(restoredTabs: const []);
      expect(session.tabs.openTabs, isEmpty);
      await session.openProjectFiles();
      expect(session.tabs.openTabs.map((tab) => tab.path), ['README.md', 'lib/main.dart']);
      expect(session.tabs.activeFile, 'README.md');
      expect(session.fileTree.state.focusedPath, '');
      await session.tabs.openWorkspaceFile('other.dart');
      session.runOrHotReload();
      expect(session.preview.state.entrypoint, 'lib/main.dart');
      expect(session.initialProject, same(initial));
      expect(initial.files, ['README.md', 'lib/main.dart']);
    } finally {
      await session.dispose();
    }
  });

  test(
    'SDK replacement retains empty root, initial metadata, edited files, current entrypoint and system tabs',
    () async {
      final contents = testProjectContents({
        'README.md': '# Project',
        'pubspec.yaml': 'name: demo',
        'lib/main.dart': 'void main() {}',
        'tool/check.dart': 'void main() {}',
      });
      final initial = InitialProjectState.resolve(
        ProjectRequest.fromUri(Uri.parse('?sdk=flutter&file=README.md')),
        contents,
        availableSdks,
      );
      final api = _Workspace();
      await ProjectLoader.writeFiles(api.root, contents);
      final systemUri = Uri.parse('file:///pub-cache/demo/main.dart');
      WorkspaceRepository repository(WorkspaceResourceApi api, {required bool dart}) => WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: dart ? availableSdks.firstWhere((sdk) => !sdk.isFlutter) : initial.sdk,
        workspaceFuture: Completer<Workspace>().future,
        customReadSystemFile: (uri) async => uri == systemUri ? 'void main() {}' : '',
      );
      final old = WorkspaceSession.create(
        repository(api, dart: false),
        initialProject: initial,
        initialMode: initial.mode,
      );
      await old.openProjectFiles();
      await old.tabs.openSystemFile(systemUri);
      final tabs = old.tabSnapshot;
      expect(tabs.clear, throwsUnsupportedError);
      final active = old.tabs.activeFile;
      await api.writeFileFromText('lib/main.dart', 'void main() { print(42); }');
      await api.deleteFileSystemEntity('pubspec.yaml');
      final copy = await old.repository.copyFiles();
      await old.dispose();
      final next = WorkspaceSession.create(
        repository(copy, dart: true),
        initialProject: initial,
        initialMode: await RunMode.resolve(
          workspace: copy,
          sdk: availableSdks.firstWhere((sdk) => !sdk.isFlutter),
          entrypoint: 'tool/check.dart',
          modeOverride: initial.request.mode,
        ),
        entrypoint: 'tool/check.dart',
      );
      try {
        expect(next.preview.previewMode, RunMode.console);
        await next.openProjectFiles(restoredTabs: tabs, activeFile: active);
        expect(
          await next.repository.workspaceResourceApi.readFileAsText('lib/main.dart'),
          'void main() { print(42); }',
        );
        expect(await next.repository.workspaceResourceApi.fileExist('pubspec.yaml'), isFalse);
        expect(next.initialProject.hasPubspec, isTrue);
        expect(next.initialProject, same(initial));
        expect(next.initialProject.root, '');
        expect(next.initialProject.sdk.isFlutter, isTrue);
        expect(next.repository.sdk.isFlutter, isFalse);
        expect(next.preview.entrypoint, 'tool/check.dart');
        expect(next.initialProject.entrypoint, 'lib/main.dart');
        expect(next.tabs.activeFile, systemUri.toString());
        expect(next.tabs.openTabs.map((tab) => tab.path), ['README.md', systemUri.toString()]);
      } finally {
        await next.dispose();
      }
    },
  );

  test('scopes the tree to the resolved root', () async {
    final contents = testProjectContents({
      'pubspec.yaml': 'name: parent',
      'lib/main.dart': 'void main() {}',
      'example/pubspec.yaml': 'name: example',
      'example/README.md': '# Example',
      'example/tool/start.dart': 'void main() {}',
    });
    final initial = InitialProjectState.resolve(
      ProjectRequest.fromUri(Uri.parse('?root=example&file=example/README.md&entrypoint=example/tool/start.dart')),
      contents,
      availableSdks,
    );
    final api = _Workspace();
    await ProjectLoader.writeFiles(api.root, contents);
    final session = WorkspaceSession.create(
      WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: initial.sdk,
        workspaceFuture: Completer<Workspace>().future,
      ),
      initialProject: initial,
      initialMode: initial.mode,
    );
    try {
      expect(session.fileTree.state.root.resource.path, 'example');
      await session.openProjectFiles();
      await session.fileTree.refresh();
      expect(session.fileTree.state.root.resource.path, 'example');
      expect(session.fileTree.state.root.exists('lib/main.dart'), isFalse);
      await session.fileTree.renameFile('example/tool/start.dart', 'other.dart');
      expect(await api.fileExist('example/tool/start.dart'), isFalse);
      expect(await api.fileExist('example/tool/other.dart'), isTrue);
    } finally {
      await session.dispose();
    }
  });
  test('document actions stay available and are no-ops for system tabs', () async {
    final workspace = _Workspace();
    await workspace.writeFileFromText('lib/main.dart', 'void main() {}');
    await workspace.writeFileFromText('pubspec.yaml', 'name: example');
    final uri = Uri.parse('file:///pub-cache/example/main.dart');
    final session = WorkspaceSession.create(
      initialProject: testProject(),
      initialMode: RunMode.flutter,
      WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: workspace,
        sdk: defaultSdk,
        workspaceFuture: Completer<Workspace>().future,
        customReadSystemFile: (u) async => u == uri ? 'void main() {}' : '',
      ),
    );
    final context = CommandContext(session: session);
    try {
      expect(formatDocumentAction.isEnabled, isNull);
      expect(saveFileAction.isEnabled, isNull);
      await session.tabs.openWorkspaceFile('lib/main.dart');
      expect(session.tabs.activeTab!.displayPath, 'lib/main.dart');
      await session.tabs.openSystemFile(uri);
      expect(session.tabs.activeTab!.origin, EditorTabOrigin.system);
      expect(session.tabs.activeTab!.isReadOnly, isTrue);
      expect(session.tabs.activeTab!.displayPath, '/pub-cache/example/main.dart');
      expect(session.tabs.activeTab!.path, uri.toString());
      await formatDocumentAction.onExecute(context);
      await saveFileAction.onExecute(context);
      expect(session.tabs.activeFile, uri.toString());
      expect(session.tabs.hasUnsavedChanges, isFalse);
      expect(session.tabs.errorMessage, isNull);
      expect(await workspace.readFileAsText('lib/main.dart'), 'void main() {}');
      expect(await workspace.fileExist(uri.toString()), isFalse);
      await session.tabs.openWorkspaceFile('pubspec.yaml');
    } finally {
      await session.dispose();
    }
  });
}

final class _TestEvent extends AsyncEvent<String> {}
