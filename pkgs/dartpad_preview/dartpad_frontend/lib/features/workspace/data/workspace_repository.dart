// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';

import '../../preview/models/run_mode.dart';
import '../../shared/app_event_bus.dart';
import '../../shared/events/error_toast_event.dart';
import '../../shared/events/log_event.dart';
import '../../shared/sdk_info.dart';
import '../../shared/task_status.dart';
import '../../startup/project_loader.dart';
import 'synced_workspace_resource_api.dart';

/// Owns project files and the worker workspace lifecycle.
base class WorkspaceRepository {
  WorkspaceRepository({
    required this.events,
    required this.taskStatus,
    required this.workspaceResourceApi,
    required this.sdk,
    required Future<Workspace> workspaceFuture,
    Future<Workspace>? readyWorkspaceFuture,
  }) : _workspaceFuture = workspaceFuture,
       _readyWorkspaceFuture = readyWorkspaceFuture ?? workspaceFuture;

  /// Shared event bus for lifecycle and diagnostic logging.
  final AppEventBus events;
  final TaskStatusController taskStatus;
  final WorkspaceResourceApi workspaceResourceApi;
  final SdkInfo sdk;
  final Future<Workspace> _workspaceFuture;
  final Future<Workspace> _readyWorkspaceFuture;

  DartPad? _dartpad;

  /// The DartPad runtime instance that owns the WASM worker.
  DartPad? get dartpad => _dartpad;

  WorkspaceFolder get root => workspaceResourceApi.root;

  /// Base URL where worker and sandbox assets are hosted.
  Uri get assetBaseUrl => sdk.assetBaseUrl;

  /// Completes once the worker workspace is ready and all writes buffered in
  /// the fallback resource API have been copied into it.
  Future<Workspace> get readyWorkspace => _readyWorkspaceFuture;

  /// Reads a file outside the project workspace directly from the worker.
  ///
  /// System files, such as SDK and pub-cache sources, intentionally bypass
  /// [workspaceResourceApi] so they do not participate in local workspace
  /// synchronization or editing.
  Future<String> readSystemFile(Uri uri) async {
    final workspace = await readyWorkspace;
    return workspace.readFileAsText(uri.toString());
  }

  factory WorkspaceRepository.create({
    required AppEventBus events,
    required SdkInfo sdk,
    required TaskStatusController taskStatus,
    WorkspaceResourceApi? localApi,
  }) {
    late final WorkspaceRepository repository;

    final workspaceFuture = (() async {
      final dartpadSdk = DartPadSdk(assetBaseUrl: sdk.assetBaseUrl);
      return await taskStatus.runTask(
        TaskKind.initializingDartPadWorker,
        () async {
          final dartpad = await dartpadSdk.dedicatedWorker();
          repository._dartpad = dartpad;
          return await dartpad.createWorkspace();
        },
        blocksPreview: true,
      );
    })();
    final api = SyncedWorkspaceResourceApi(
      localApi: localApi ?? MemoryWorkspaceResourceApi(),
      remoteApi: workspaceFuture.then(WorkerWorkspaceResourceApi.new),
      onLocalToRemoteSyncError: (_, _) {
        events.dispatch(const ErrorToastEvent('Saving failed, try again'));
      },
      onRemoteToLocalSyncError: (_, _) {
        events.dispatch(const ErrorToastEvent('Something went wrong, please try again'));
      },
    );
    final readyWorkspaceFuture = api.apiReady.then((_) => workspaceFuture);
    return repository = WorkspaceRepository(
      events: events,
      taskStatus: taskStatus,
      workspaceResourceApi: api,
      sdk: sdk,
      workspaceFuture: workspaceFuture,
      readyWorkspaceFuture: readyWorkspaceFuture,
    );
  }

  Future<void> _runPubCommand({
    required TaskKind kind,
    required String commandName,
    String path = '',
    String projectRoot = '',
    bool blocksPreview = false,
  }) {
    final normalizedPath = normalizeWorkspacePath(path);
    final pathLabel = _displayPathRelativeToProject(
      path: normalizedPath,
      projectRoot: projectRoot,
    );
    return taskStatus.runTask(
      kind,
      () => runWorkspacePubCommand(
        events: events,
        commandName: commandName,
        path: path,
        projectRoot: projectRoot,
        command: (normalizedPath) async {
          final workspace = await _workspaceFuture;
          final api = workspaceResourceApi;
          if (api is SyncedWorkspaceResourceApi) {
            await api.flush();
          }
          final result = await workspace.pub(uri: normalizedPath, command: commandName);
          return result.log;
        },
      ),
      label: '${kind.label} in $pathLabel',
      scope: normalizedPath.toString(),
      blocksPreview: blocksPreview,
    );
  }

  Future<void> pubGet({String path = '', String projectRoot = ''}) => _runPubCommand(
    kind: TaskKind.pubGet,
    commandName: 'get',
    path: path,
    projectRoot: projectRoot,
    blocksPreview: true,
  );

  Future<void> pubUpgrade({String path = '', String projectRoot = ''}) => _runPubCommand(
    kind: TaskKind.pubUpgrade,
    commandName: 'upgrade',
    path: path,
    projectRoot: projectRoot,
    blocksPreview: true,
  );

  Future<void> pubDowngrade({String path = '', String projectRoot = ''}) => _runPubCommand(
    kind: TaskKind.pubDowngrade,
    commandName: 'downgrade',
    path: path,
    projectRoot: projectRoot,
    blocksPreview: true,
  );

  Future<void> pubOutdated({String path = '', String projectRoot = ''}) => _runPubCommand(
    kind: TaskKind.pubOutdated,
    commandName: 'outdated',
    path: path,
    projectRoot: projectRoot,
    blocksPreview: false,
  );

  /// Removes generated Pub and build output from the workspace.
  Future<void> pubClean({String path = ''}) async {
    final normalizedPath = normalizeWorkspacePath(path);
    final pathLabel = _displayPathRelativeToProject(
      path: normalizedPath,
      projectRoot: '',
    );
    await taskStatus.runTask(
      TaskKind.pubClean,
      () async {
        events.dispatch(const LogEvent('Cleaning workspace...'));
        final api = workspaceResourceApi;
        if (api is SyncedWorkspaceResourceApi) {
          await api.flush();
        }
        await cleanGeneratedOutput(workspaceResourceApi, path: path);
        events.dispatch(const LogEvent('Cleaning workspace... Done'));
      },
      label: 'Pub clean in $pathLabel',
      scope: normalizedPath.toString(),
      blocksPreview: true,
    );
  }

  /// Deletes generated directories when they exist.
  static Future<void> cleanGeneratedOutput(
    WorkspaceResourceApi workspace, {
    String path = '',
  }) async {
    final buildPath = joinWorkspacePath(path, 'build');
    final dartToolPath = joinWorkspacePath(path, '.dart_tool');
    if (await workspace.folderExist(buildPath)) {
      await workspace.deleteFileSystemEntity(buildPath);
    }
    if (await workspace.folderExist(dartToolPath)) {
      await workspace.deleteFileSystemEntity(dartToolPath);
    }
  }

  Future<void> close() async {
    try {
      await workspaceResourceApi.dispose();
    } finally {
      await dartpad?.dispose();
    }
  }

  /// Disposes the current workspace API **without** terminating the worker.
  ///
  /// During a reset, complete the [resetAndCreate] disposal barrier only after
  /// this cleanup finishes.
  Future<void> closeWorkspaceOnly() => workspaceResourceApi.dispose();

  /// Creates a fresh [WorkspaceRepository] reusing the existing DartPad
  /// [worker].
  ///
  /// The caller remains responsible for disposing the previous repository via
  /// [closeWorkspaceOnly] once its UI subtree has unmounted. The worker is
  /// shared with the new repository (exposed through [dartpad]), but the new
  /// worker workspace is not created until [previousWorkspaceDisposed]
  /// completes. Readiness is exposed through [readyWorkspace].
  static WorkspaceRepository resetAndCreate({
    required AppEventBus events,
    required DartPad worker,
    required SdkInfo sdk,
    required TaskStatusController taskStatus,
    required Future<void> previousWorkspaceDisposed,
    WorkspaceResourceApi? localApi,
  }) {
    final workspaceFuture = (() async {
      await previousWorkspaceDisposed;
      final workspace = await taskStatus.runTask(
        TaskKind.initializingDartPadWorker,
        worker.createWorkspace,
        blocksPreview: true,
      );
      return workspace;
    })();

    final api = SyncedWorkspaceResourceApi(
      localApi: localApi ?? MemoryWorkspaceResourceApi(),
      remoteApi: workspaceFuture.then(WorkerWorkspaceResourceApi.new),
      onLocalToRemoteSyncError: (_, _) {
        events.dispatch(const ErrorToastEvent('Saving failed, try again'));
      },
      onRemoteToLocalSyncError: (_, _) {
        events.dispatch(const ErrorToastEvent('Something went wrong, please try again'));
      },
    );
    final readyWorkspaceFuture = api.apiReady.then((_) => workspaceFuture);
    return WorkspaceRepository(
      events: events,
      taskStatus: taskStatus,
      workspaceResourceApi: api,
      sdk: sdk,
      workspaceFuture: workspaceFuture,
      readyWorkspaceFuture: readyWorkspaceFuture,
    ).._dartpad = worker;
  }

  Future<RunMode> runModeFor(String entrypoint) =>
      RunMode.resolve(workspace: workspaceResourceApi, sdk: sdk, entrypoint: entrypoint);

  /// Copies current bytes into an independent workspace for an SDK switch.
  Future<MemoryWorkspaceResourceApi> copyFiles() async {
    await flush();
    final copy = MemoryWorkspaceResourceApi();
    try {
      final resources = await root.getChildren(recursive: true);
      await ProjectLoader.writeFiles(
        copy.root,
        Project([
          for (final file in resources.whereType<WorkspaceFile>())
            ProjectFile(path: file.path, bytes: await workspaceResourceApi.readFileAsBytes(file.path)),
        ]),
      );
      return copy;
    } catch (_) {
      await copy.dispose();
      rethrow;
    }
  }

  /// Completes all queued local writes before a sandbox compiles sources.
  Future<void> flush() async {
    final api = workspaceResourceApi;
    if (api is SyncedWorkspaceResourceApi) {
      await api.flush();
    }
  }
}

/// Returns a user-facing path relative to the active [projectRoot].
///
/// The project root itself is displayed as `/`.
String _displayPathRelativeToProject({
  required String path,
  required String projectRoot,
}) {
  final normalizedPath = normalizeWorkspacePath(path);
  final normalizedRoot = normalizeWorkspacePath(projectRoot);

  if (normalizedPath == normalizedRoot) {
    return '/';
  }
  if (normalizedRoot.isNotEmpty && normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  if (normalizedRoot.isNotEmpty) {
    return workspacePath.relative(normalizedPath, from: normalizedRoot);
  }
  return normalizedPath.isEmpty ? '/' : normalizedPath;
}

/// Runs a Pub command and forwards its output to the application debug console.
Future<void> runWorkspacePubCommand({
  required AppEventBus events,
  required String commandName,
  required String path,
  required String projectRoot,
  required Future<String> Function(String normalizedPath) command,
}) async {
  final normalizedPath = normalizeWorkspacePath(path);
  final pathLabel = _displayPathRelativeToProject(
    path: normalizedPath,
    projectRoot: projectRoot,
  );
  events.dispatch(LogEvent('Running pub $commandName in $pathLabel'));
  final log = await command(normalizedPath);
  if (log.isNotEmpty) {
    events.dispatch(LogEvent(log));
  }
}
