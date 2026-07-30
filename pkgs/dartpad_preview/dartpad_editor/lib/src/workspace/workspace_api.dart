// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:dartpad/dartpad.dart';

import 'workspace_events.dart';
import 'workspace_path.dart';
import 'workspace_resource.dart';

/// Provides access to the files and directories of a virtual workspace.
abstract interface class WorkspaceResourceApi {
  /// Checks whether a file exists at the given [uri].
  Future<bool> fileExist(String uri);

  /// Checks whether a folder exists at the given [uri].
  Future<bool> folderExist(String uri);

  /// Reads the file contents at the given [uri] as a UTF-8 string.
  Future<String> readFileAsText(String uri);

  /// Reads the file contents at the given [uri] as a byte buffer.
  Future<Uint8List> readFileAsBytes(String uri);

  /// Writes [content] text into the file at the given [uri].
  Future<void> writeFileFromText(String uri, String content);

  /// Writes [bytes] into the file at the given [uri].
  Future<void> writeFileFromBytes(String uri, Uint8List bytes);

  /// Creates a directory folder at the given [uri].
  Future<void> createFolder(String uri);

  /// Deletes the file or directory at the given [uri].
  Future<void> deleteFileSystemEntity(String uri);

  /// Lists the contents of the directory folder at the given [uri].
  ///
  /// If [recursive] is true, traverses all subfolders recursively.
  /// Returns a list of entry records containing the relative path and type ('file' or 'folder').
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false});

  /// Registers an intention to move/rename a resource from [oldPath] to [newPath].
  void addMoveIntention(String oldPath, String newPath);

  /// Emits reconciled file change events representing addition, removal, modification, and moves.
  Stream<WorkspaceChangeEvent> get changeEvents;

  /// Completes when the filesystem change observer is ready.
  Future<void> get changeEventsReady;

  /// Disposes of any resources held by this workspace resource api.
  Future<void> dispose();
}

extension RootResource on WorkspaceResourceApi {
  /// The root [WorkspaceFolder] of the workspace.
  WorkspaceFolder get root => WorkspaceFolder(workspace: this, path: '');
}

/// An in-memory implementation of [WorkspaceResourceApi] utilizing [MemoryResourceProvider]
/// from the analyzer package.
class MemoryWorkspaceResourceApi with WorkspaceResourceEventsMixin implements WorkspaceResourceApi {
  final ResourceProvider _rp = MemoryResourceProvider(context: workspacePath);
  late final Folder _root = _rp.getFolder('/root')..create();
  late final ResourceWatcher _rpWatcher = _root.watch();

  @override
  Future<bool> fileExist(String uri) => Future.value(_root.getChildAssumingFile(uri).exists);

  @override
  Future<bool> folderExist(String uri) => Future.value(_root.getChildAssumingFolder(uri).exists);

  @override
  Future<String> readFileAsText(String uri) => Future.value(_root.getChildAssumingFile(uri).readAsStringSync());

  @override
  Future<Uint8List> readFileAsBytes(String uri) => Future.value(_root.getChildAssumingFile(uri).readAsBytesSync());

  @override
  Future<void> writeFileFromText(String uri, String content) async {
    _root.getChildAssumingFile(uri).writeAsStringSync(content);
  }

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) async {
    _root.getChildAssumingFile(uri).writeAsBytesSync(bytes);
  }

  @override
  Future<void> createFolder(String uri) async {
    _root.getChildAssumingFolder(uri).create();
  }

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    final file = _root.getChildAssumingFile(uri);
    if (file.exists) {
      file.delete();
      return;
    }
    final folder = _root.getChildAssumingFolder(uri);
    if (folder.exists) {
      folder.delete();
      return;
    }
  }

  @override
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false}) async {
    final folder = _root.getChildAssumingFolder(uri);
    if (!folder.exists) {
      return [];
    }

    final result = <({String path, String type})>[];
    void visit(Folder f) {
      for (final child in f.getChildren()) {
        final relPath = workspacePath.relative(child.path, from: folder.path);
        result.add((
          path: relPath,
          type: child is Folder ? 'folder' : 'file',
        ));
        if (recursive && child is Folder) {
          visit(child);
        }
      }
    }

    visit(folder);
    return result;
  }

  @override
  Stream<FileChangeEvent> get rawFileChanges => _rpWatcher.changes.map((e) {
    final relativePath = workspacePath.relative(e.path, from: '/root');
    return switch (e.type) {
      .ADD => FileAddedEvent(Uri.parse(relativePath)),
      .REMOVE => FileRemovedEvent(Uri.parse(relativePath)),
      .MODIFY || _ => FileModifiedEvent(Uri.parse(relativePath)),
    };
  });

  @override
  Future<void> get changeEventsReady => _rpWatcher.ready;

  @override
  Future<void> dispose() => Future.value();
}

/// An implementation of [WorkspaceResourceApi] that wraps a Workspace instance,
/// delegating operations to a remote Worker process and translating the resulting paths.
class WorkerWorkspaceResourceApi with WorkspaceResourceEventsMixin implements WorkspaceResourceApi {
  WorkerWorkspaceResourceApi(this._workspace);

  final Workspace _workspace;
  late final WorkspaceWatcher _workspaceWatcher = _workspace.watch('/');

  @override
  Future<bool> fileExist(String uri) => _workspace.fileExist(uri);

  @override
  Future<bool> folderExist(String uri) => _workspace.folderExist(uri);

  @override
  Future<String> readFileAsText(String uri) => _workspace.readFileAsText(uri);

  @override
  Future<Uint8List> readFileAsBytes(String uri) => _workspace.readFileAsBytes(uri);

  @override
  Future<void> writeFileFromText(String uri, String content) => _workspace.writeFileFromText(uri, content);

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) => _workspace.writeFileFromBytes(uri, bytes);

  @override
  Future<void> createFolder(String uri) => _workspace.createFolder(uri);

  @override
  Future<void> deleteFileSystemEntity(String uri) => _workspace.deleteFileSystemEntity(uri);

  @override
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false}) =>
      _workspace.listDirectory(uri: uri, recursive: recursive);

  @override
  Stream<FileChangeEvent> get rawFileChanges => _workspaceWatcher.changes.expand((event) {
    final result = _mapEventToRelativePath(event);
    return [?result];
  });

  FileChangeEvent? _mapEventToRelativePath(FileChangeEvent event) {
    final relativePath = _relativePath(event.uri);
    if (relativePath == null) {
      return null;
    }
    return switch (event) {
      FileAddedEvent() => FileAddedEvent(Uri.parse(relativePath)),
      FileRemovedEvent() => FileRemovedEvent(Uri.parse(relativePath)),
      FileModifiedEvent() => FileModifiedEvent(Uri.parse(relativePath)),
    };
  }

  String? _relativePath(Uri uri) {
    final root = _workspace.workspaceFolder;
    if (!uri.hasScheme) {
      return uri.path.replaceFirst(RegExp(r'^/+'), '');
    }

    if (uri.scheme != root.scheme || uri.authority != root.authority) {
      return null;
    }
    final rootPath = root.path.endsWith('/') ? root.path : '${root.path}/';
    if (!uri.path.startsWith(rootPath)) {
      return null;
    }
    return Uri.decodeComponent(uri.path.substring(rootPath.length));
  }

  @override
  Future<void> get changeEventsReady => _workspaceWatcher.ready;

  @override
  Future<void> dispose() => _workspace.dispose();
}

/// An implementation of [WorkspaceResourceApi] that initially delegates to a local fallback API
/// (such as [MemoryWorkspaceResourceApi]) while asynchronously loading a remote future API.
///
/// Once the remote API is loaded, it copies all local file system resources to it,
/// and routes all subsequent operations to it.
class DeferredWorkspaceResourceApi implements WorkspaceResourceApi {
  DeferredWorkspaceResourceApi.fromFutureAndFallback(
    Future<WorkspaceResourceApi> apiFuture,
    WorkspaceResourceApi fallbackApi,
  ) {
    _api = fallbackApi;
    _workspaceLoadingFuture = () async {
      final ws = await apiFuture;
      final completer = Completer<void>();
      _workspaceInitLock = completer.future;
      try {
        final resources = await _api.listDirectory(uri: '', recursive: true);
        for (final r in resources) {
          if (r.type == 'folder') {
            await ws.createFolder(r.path);
          } else {
            await ws.writeFileFromBytes(r.path, await _api.readFileAsBytes(r.path));
          }
        }
        _api = ws;
      } finally {
        completer.complete();
        _workspaceInitLock = null;
        _workspaceLoadingFuture = null;
      }
    }();
  }

  late WorkspaceResourceApi _api;
  Future<void>? _workspaceLoadingFuture;
  Future<void>? _workspaceInitLock;

  Future<void> get apiReady => _workspaceLoadingFuture ?? Future.value();

  @override
  Future<bool> fileExist(String uri) async {
    await _workspaceInitLock;
    return _api.fileExist(uri);
  }

  @override
  Future<bool> folderExist(String uri) async {
    await _workspaceInitLock;
    return _api.folderExist(uri);
  }

  @override
  Future<String> readFileAsText(String uri) async {
    await _workspaceInitLock;
    return _api.readFileAsText(uri);
  }

  @override
  Future<Uint8List> readFileAsBytes(String uri) async {
    await _workspaceInitLock;
    return _api.readFileAsBytes(uri);
  }

  @override
  Future<void> writeFileFromText(String uri, String content) async {
    await _workspaceInitLock;
    return _api.writeFileFromText(uri, content);
  }

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) async {
    await _workspaceInitLock;
    return _api.writeFileFromBytes(uri, bytes);
  }

  @override
  Future<void> createFolder(String uri) async {
    await _workspaceInitLock;
    return _api.createFolder(uri);
  }

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    await _workspaceInitLock;
    return _api.deleteFileSystemEntity(uri);
  }

  @override
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false}) async {
    await _workspaceInitLock;
    return _api.listDirectory(uri: uri, recursive: recursive);
  }

  @override
  void addMoveIntention(String oldPath, String newPath) {
    _api.addMoveIntention(oldPath, newPath);
  }

  @override
  Stream<WorkspaceChangeEvent> get changeEvents {
    if (_workspaceLoadingFuture == null) {
      return _api.changeEvents;
    }

    late final StreamController<WorkspaceChangeEvent> controller;
    StreamSubscription<dynamic>? subscription;

    controller = StreamController<WorkspaceChangeEvent>(
      onListen: () {
        final loading = _workspaceLoadingFuture;
        if (loading == null) {
          subscription = _api.changeEvents.listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
        } else {
          subscription = _api.changeEvents.listen(
            controller.add,
            onError: controller.addError,
          );

          loading.then((_) {
            if (controller.hasListener) {
              subscription?.cancel();
              subscription = _api.changeEvents.listen(
                controller.add,
                onError: controller.addError,
                onDone: controller.close,
              );
            }
          });
        }
      },
      onCancel: () {
        subscription?.cancel();
        subscription = null;
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
    );

    return controller.stream;
  }

  @override
  Future<void> get changeEventsReady async {
    await _workspaceInitLock;
    return _api.changeEventsReady;
  }

  @override
  Future<void> dispose() async {
    await _api.dispose();
  }
}
