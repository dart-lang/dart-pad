// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

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

/// Owns project files and their dedicated worker's lifecycle.
final class WorkspaceRepository {
  WorkspaceRepository({
    required this.events,
    required this.taskStatus,
    required this.workspaceResourceApi,
    required this.sdk,
    Future<Workspace>? workspaceFuture,
    Future<Workspace>? readyWorkspaceFuture,
    this.dartpad,
    this.onFlush,
    this.customReadSystemFile,
    this.createWorker,
  }) : _workspaceFuture = workspaceFuture,
       _readyWorkspaceFuture = readyWorkspaceFuture ?? workspaceFuture {
    // Startup may fail while callers are still opening tabs or saving files.
    // Handle errors immediately; later awaits still receive the original error.
    _readyWorkspaceFuture?.ignore();
  }

  /// Shared event bus for lifecycle and diagnostic logging.
  final AppEventBus events;
  final TaskStatusController taskStatus;
  final WorkspaceResourceApi workspaceResourceApi;
  final SdkInfo sdk;
  Future<Workspace>? _workspaceFuture;
  Future<Workspace>? _readyWorkspaceFuture;
  int _workerGeneration = 0;

  /// Optional worker factory override, used for lifecycle tests.
  final Future<DartPad> Function()? createWorker;

  /// Optional system file reader override, used for tests.
  final Future<String> Function(Uri uri)? customReadSystemFile;

  /// Callback override for [flush] during testing.
  Future<void> Function()? onFlush;

  /// The DartPad runtime instance that owns the WASM worker.
  DartPad? dartpad;
  bool _isClosed = false;
  Future<void>? _closeFuture;
  int _closeCount = 0;

  /// Whether [close] has been initiated.
  bool get isClosed => _isClosed;

  /// The number of times [close] was called.
  int get closeCount => _closeCount;

  bool get hasRuntime => _workspaceFuture != null;

  WorkspaceFolder get root => workspaceResourceApi.root;

  /// Base URL where worker and sandbox assets are hosted.
  Uri get assetBaseUrl => sdk.assetBaseUrl;

  /// Completes once the worker workspace is ready and all writes buffered in
  /// the fallback resource API have been copied into it.
  Future<Workspace> get readyWorkspace =>
      _readyWorkspaceFuture ?? Future.error(StateError('The workspace runtime is inactive.'));

  /// Reads a file outside the project workspace directly from the worker.
  ///
  /// System files, such as SDK and pub-cache sources, intentionally bypass
  /// [workspaceResourceApi] so they do not participate in local workspace
  /// synchronization or editing.
  Future<String> readSystemFile(Uri uri) async {
    final customReader = customReadSystemFile;
    if (customReader != null) {
      return customReader(uri);
    }
    final workspace = await readyWorkspace;
    return workspace.readFileAsText(uri.toString());
  }

  /// Starts a dedicated worker and synchronizes [localApi] into its workspace.
  /// [createWorker] can supply controlled worker startup for lifecycle tests.
  factory WorkspaceRepository.create({
    required AppEventBus events,
    required SdkInfo sdk,
    required TaskStatusController taskStatus,
    WorkspaceResourceApi? localApi,
    Future<DartPad> Function()? createWorker,
    bool deferWorker = false,
  }) {
    final api = SyncedWorkspaceResourceApi(
      localApi: localApi ?? MemoryWorkspaceResourceApi(),
      onLocalToRemoteSyncError: (_, _) {
        events.dispatch(const ErrorToastEvent('Saving failed, try again'));
      },
      onRemoteToLocalSyncError: (_, _) {
        events.dispatch(const ErrorToastEvent('Something went wrong, please try again'));
      },
    );
    final repository = WorkspaceRepository(
      events: events,
      taskStatus: taskStatus,
      workspaceResourceApi: api,
      sdk: sdk,
      createWorker: createWorker,
    );
    if (!deferWorker) {
      repository.startWorker().ignore();
    }
    return repository;
  }

  /// Starts or reuses the runtime, synchronizing the retained local files.
  /// Embedded editors call this only when explicitly activated.
  Future<Workspace> startWorker() {
    if (_isClosed) {
      return Future.error(StateError('The workspace is closed.'));
    }
    if (_workspaceFuture != null) {
      return readyWorkspace;
    }
    final generation = ++_workerGeneration;
    final workspaceFuture = taskStatus.runTask(
      TaskKind.initializingDartPadWorker,
      () async {
        final worker = await (createWorker?.call() ?? DartPadSdk(assetBaseUrl: sdk.assetBaseUrl).dedicatedWorker());
        if (_isClosed || generation != _workerGeneration) {
          // The runtime can be suspended while its SDK loads.
          await worker.dispose();
          throw StateError(
            _isClosed
                ? 'Workspace repository closed during worker initialization.'
                : 'The workspace runtime was deactivated.',
          );
        }
        dartpad = worker;
        return worker.createWorkspace();
      },
      blocksPreview: true,
    );
    _workspaceFuture = workspaceFuture;
    final api = workspaceResourceApi as SyncedWorkspaceResourceApi;
    api.connect(workspaceFuture.then(WorkerWorkspaceResourceApi.new));
    final ready = _readyWorkspaceFuture = api.apiReady.then((_) => workspaceFuture);
    ready.ignore();
    return ready;
  }

  /// Retires worker resources without disposing project files or editor tabs.
  Future<void> suspendWorker() async {
    _workerGeneration++;
    final worker = dartpad;
    dartpad = null;
    _workspaceFuture = null;
    _readyWorkspaceFuture = null;
    final api = workspaceResourceApi;
    try {
      if (api is SyncedWorkspaceResourceApi) {
        await api.disconnect(disposeRemote: false);
      }
    } finally {
      await worker?.dispose();
    }
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
          final workspace = await readyWorkspace;
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

  /// Closes this workspace and its worker once, including a worker still starting.
  Future<void> close() {
    _closeCount++;
    return _closeFuture ??= _close();
  }

  Future<void> _close() async {
    _isClosed = true;
    try {
      await suspendWorker();
    } finally {
      await workspaceResourceApi.dispose();
    }
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
    final customFlush = onFlush;
    if (customFlush != null) {
      await customFlush();
      return;
    }
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
