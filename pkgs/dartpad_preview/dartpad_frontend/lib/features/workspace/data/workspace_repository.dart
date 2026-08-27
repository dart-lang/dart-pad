// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:web/web.dart' as web;

import '../../preview/models/compiler_session.dart';
import '../../shared/app_event_bus.dart';
import '../../shared/events/error_toast_event.dart';
import '../../shared/events/log_event.dart';
import 'synced_workspace_resource_api.dart';

/// Owns the complete worker-side workspace lifecycle for the transient app.
class WorkspaceRepository {
  WorkspaceRepository({
    required this.events,
    required this.workspaceResourceApi,
    required Future<Workspace> workspaceFuture,
    Future<Workspace>? readyWorkspaceFuture,
  }) : _workspaceFuture = workspaceFuture,
       _readyWorkspaceFuture = readyWorkspaceFuture ?? workspaceFuture;

  /// Shared event bus for lifecycle and diagnostic logging.
  final AppEventBus events;
  final WorkspaceResourceApi workspaceResourceApi;
  final Future<Workspace> _workspaceFuture;
  final Future<Workspace> _readyWorkspaceFuture;

  /// The DartPad runtime instance that owns the WASM worker.
  DartPad? dartpad;

  WorkspaceFolder get root => workspaceResourceApi.root;

  /// Completes once the worker workspace is ready and all writes buffered in
  /// the fallback resource API have been copied into it.
  Future<Workspace> get readyWorkspace => _readyWorkspaceFuture;

  factory WorkspaceRepository.create({required AppEventBus events}) {
    late final WorkspaceRepository repository;

    final workspaceFuture = (() async {
      final sdk = DartPadSdk(assetBaseUrl: Uri.parse(web.document.baseURI).resolve('dartpad/flutter/'));
      final dartpad = await sdk.dedicatedWorker();
      repository.dartpad = dartpad;
      final workspace = await dartpad.createWorkspace();
      return workspace;
    })();
    final api = SyncedWorkspaceResourceApi(
      localApi: MemoryWorkspaceResourceApi(),
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
      workspaceResourceApi: api,
      workspaceFuture: workspaceFuture,
      readyWorkspaceFuture: readyWorkspaceFuture,
    );
  }

  Future<void> pubGet({String path = '', String projectRoot = ''}) => runWorkspacePubGet(
    events: events,
    path: path,
    projectRoot: projectRoot,
    command: (normalizedPath) async {
      final workspace = await _workspaceFuture;
      final api = workspaceResourceApi;
      if (api is SyncedWorkspaceResourceApi) {
        await api.flush();
      }
      final result = await workspace.pub(uri: normalizedPath, command: 'get');
      return result.log;
    },
  );

  /// Removes generated Pub and build output from the workspace.
  Future<void> pubClean({String path = ''}) async {
    events.dispatch(const LogEvent('Cleaning workspace...'));
    final api = workspaceResourceApi;
    if (api is SyncedWorkspaceResourceApi) {
      await api.flush();
    }
    await cleanGeneratedOutput(workspaceResourceApi, path: path);
    events.dispatch(const LogEvent('Cleaning workspace... Done'));
  }

  /// Deletes generated directories when they exist.
  static Future<void> cleanGeneratedOutput(
    WorkspaceResourceApi workspace, {
    String path = '',
  }) async {
    final buildPath = workspaceContext.join(path, 'build');
    final dartToolPath = workspaceContext.join(path, '.dart_tool');
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
  /// shared with the new repository (its [dartpad] field is set), but the new
  /// worker workspace is not created until [previousWorkspaceDisposed]
  /// completes. Readiness is exposed through [readyWorkspace].
  static WorkspaceRepository resetAndCreate({
    required AppEventBus events,
    required DartPad worker,
    required Future<void> previousWorkspaceDisposed,
  }) {
    final workspaceFuture = (() async {
      await previousWorkspaceDisposed;
      final workspace = await worker.createWorkspace();
      return workspace;
    })();

    final api = SyncedWorkspaceResourceApi(
      localApi: MemoryWorkspaceResourceApi(),
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
      workspaceResourceApi: api,
      workspaceFuture: workspaceFuture,
      readyWorkspaceFuture: readyWorkspaceFuture,
    )..dartpad = worker;
  }

  Future<CompilerSession> startHotReloadCompiler(Uri uri) async {
    final workspace = await _workspaceFuture;
    final api = workspaceResourceApi;
    final compiler = await workspace.startHotReloadCompiler(uri);
    return RealCompilerSession(
      compiler,
      onBeforeCompile: api is SyncedWorkspaceResourceApi ? api.flush : null,
    );
  }

  /// Converts a workspace [filePath] to a `package:` URI based on the nearest
  /// resolved package configuration or pubspec.yaml.
  Future<Uri> convertToPackageUri(String filePath) async {
    String? resolvedPackageName;
    WorkspaceFolder? resolvedFolder;

    // 1. Search for package_config.json in all parent folders (from bottom to top)
    WorkspaceFolder folder = root.getFile(filePath).parent;
    while (true) {
      final config = folder.getFile('.dart_tool/package_config.json');
      if (await config.exists()) {
        try {
          final content = await config.readContent();
          final configJson = json.decode(content) as Map<String, dynamic>;
          final packages = configJson['packages'] as List<dynamic>?;
          if (packages != null) {
            for (final pkg in packages) {
              final map = pkg as Map<String, dynamic>;
              if (map['rootUri'] == '../') {
                resolvedPackageName = map['name'] as String;
                resolvedFolder = folder;
                break;
              }
            }
          }
        } catch (_) {
          // Fall through.
        }
      }
      if (resolvedPackageName != null) {
        break;
      }

      if (folder.isRoot) {
        break;
      }
      folder = folder.parent;
    }

    // 2. Search for pubspec.yaml in all parent folders (from bottom to top)
    if (resolvedPackageName == null) {
      folder = root.getFile(filePath).parent;
      while (true) {
        final pubspec = folder.getFile('pubspec.yaml');
        if (await pubspec.exists()) {
          final content = await pubspec.readContent();
          final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
          if (match != null) {
            resolvedPackageName = match.group(1)!.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
            resolvedFolder = folder;
            break;
          }
        }

        if (folder.isRoot) {
          break;
        }
        folder = folder.parent;
      }
    }

    final packageName = resolvedPackageName ?? 'app';
    final packageFolder = resolvedFolder ?? root;

    final libFolder = workspaceContext.join(packageFolder.path, 'lib');
    if (workspacePath.isWithin(libFolder, filePath)) {
      final relativePath = workspacePath.relative(filePath, from: libFolder);
      return Uri(
        scheme: 'package',
        path: workspacePath.join(packageName, relativePath),
      );
    } else {
      final ws = await _workspaceFuture;
      return ws.workspaceFolder.resolve(filePath);
    }
  }

  /// Checks if the project containing [filePath] has a dependency on the
  /// flutter framework by reading its resolved `.dart_tool/package_config.json`.
  Future<bool> hasFlutterDependency(String filePath) async {
    WorkspaceFolder folder = root.getFile(filePath).parent;
    while (true) {
      final config = folder.getFile('.dart_tool/package_config.json');
      if (await config.exists()) {
        try {
          final content = await config.readContent();
          final configJson = json.decode(content) as Map<String, dynamic>;
          final packages = configJson['packages'] as List<dynamic>?;
          if (packages != null) {
            for (final pkg in packages) {
              final map = pkg as Map<String, dynamic>;
              if (map['name'] == 'flutter') {
                return true;
              }
            }
            return false;
          }
        } catch (_) {
          // Fall through.
        }
      }

      if (folder.isRoot) {
        break;
      }
      folder = folder.parent;
    }
    return false;
  }
}

/// Runs Pub Get and forwards its output to the application debug console.
Future<void> runWorkspacePubGet({
  required AppEventBus events,
  required String path,
  required String projectRoot,
  required Future<String> Function(String normalizedPath) command,
}) async {
  final normalizedPath = workspaceContext.normalize(path);
  final pathLabel = workspaceContext.relativeDisplayPath(
    path: normalizedPath,
    projectRoot: projectRoot,
  );
  events.dispatch(LogEvent('Running pub get in $pathLabel'));
  final log = await command(normalizedPath);
  if (log.isNotEmpty) {
    events.dispatch(LogEvent(log));
  }
}
