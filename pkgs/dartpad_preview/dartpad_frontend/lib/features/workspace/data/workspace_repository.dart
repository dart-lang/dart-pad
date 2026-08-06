// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';
import '../../shared/events/workspace_event.dart';
import '../../preview/models/compiler_session.dart';

/// Owns the complete worker-side workspace lifecycle for the transient app.
class WorkspaceRepository {
  WorkspaceRepository({
    required this.events,
    required this.workspaceResourceApi,
    required this._workspaceFuture,
  });

  /// Shared event bus for lifecycle and diagnostic logging.
  final AppEventBus events;
  final WorkspaceResourceApi workspaceResourceApi;
  final Future<Workspace> _workspaceFuture;

  /// The DartPad runtime instance that owns the WASM worker.
  DartPad? dartpad;

  WorkspaceFolder get root => workspaceResourceApi.root;

  factory WorkspaceRepository.create({required AppEventBus events}) {
    late final WorkspaceRepository repository;

    final workspaceFuture = (() async {
      final sdk = DartPadSdk(assetBaseUrl: Uri.parse(web.document.baseURI).resolve('dartpad/flutter/'));
      final dartpad = await sdk.dedicatedWorker();
      repository.dartpad = dartpad;
      final workspace = await dartpad.createWorkspace();
      return workspace;
    })();
    final api = DeferredWorkspaceResourceApi.fromFutureAndFallback(
      workspaceFuture.then(WorkerWorkspaceResourceApi.new),
      MemoryWorkspaceResourceApi(),
    );
    api.apiReady.then((_) {
      workspaceFuture.then((ws) {
        events.dispatch(WorkspaceLoadedEvent(ws));
      });
    });
    return repository = WorkspaceRepository(
      events: events,
      workspaceResourceApi: api,
      workspaceFuture: workspaceFuture,
    );
  }

  Future<void> pubGet({String path = '', String projectRoot = ''}) => runWorkspacePubGet(
    events: events,
    path: path,
    projectRoot: projectRoot,
    command: (normalizedPath) async {
      final workspace = await _workspaceFuture;
      final result = await workspace.pub(uri: normalizedPath, command: 'get');
      return result.log;
    },
  );

  /// Removes generated Pub and build output from the workspace.
  Future<void> pubClean({String path = ''}) async {
    events.dispatch(const LogEvent('Cleaning workspace...'));
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
    await workspaceResourceApi.dispose();
    await dartpad?.dispose();
  }

  Future<CompilerSession> startHotReloadCompiler(Uri uri) async {
    final workspace = await _workspaceFuture;
    final compiler = await workspace.startHotReloadCompiler(uri);
    return RealCompilerSession(compiler);
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
    final relativePath = workspacePath.relative(filePath, from: libFolder);
    return Uri(
      scheme: 'package',
      path: workspacePath.join(packageName, relativePath),
    );
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

