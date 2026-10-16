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
///
/// Paths are workspace-relative file paths using `/`, with an empty string
/// identifying the root.
abstract interface class WorkspaceResourceApi {
  /// Checks whether a file exists at the given [path].
  Future<bool> fileExist(String path);

  /// Checks whether a folder exists at the given [path].
  Future<bool> folderExist(String path);

  /// Reads the file contents at the given [path] as a UTF-8 string.
  Future<String> readFileAsText(String path);

  /// Reads the file contents at the given [path] as a byte buffer.
  Future<Uint8List> readFileAsBytes(String path);

  /// Writes [content] text into the file at the given [path].
  Future<void> writeFileFromText(String path, String content);

  /// Writes [bytes] into the file at the given [path].
  Future<void> writeFileFromBytes(String path, Uint8List bytes);

  /// Creates a directory folder at the given [path].
  Future<void> createFolder(String path);

  /// Deletes the file or directory at the given [path].
  Future<void> deleteFileSystemEntity(String path);

  /// Lists the contents of the directory folder at the given [path].
  ///
  /// If [recursive] is true, traverses all subfolders recursively.
  /// Returns entries with paths relative to [path] and type ('file' or 'folder').
  Future<List<({String path, String type})>> listDirectory({required String path, bool recursive = false});

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
  Future<bool> fileExist(String path) => Future.value(_root.getChildAssumingFile(path).exists);

  @override
  Future<bool> folderExist(String path) => Future.value(_root.getChildAssumingFolder(path).exists);

  @override
  Future<String> readFileAsText(String path) => Future.value(_root.getChildAssumingFile(path).readAsStringSync());

  @override
  Future<Uint8List> readFileAsBytes(String path) => Future.value(_root.getChildAssumingFile(path).readAsBytesSync());

  @override
  Future<void> writeFileFromText(String path, String content) async {
    _root.getChildAssumingFile(path).writeAsStringSync(content);
  }

  @override
  Future<void> writeFileFromBytes(String path, Uint8List bytes) async {
    _root.getChildAssumingFile(path).writeAsBytesSync(bytes);
  }

  @override
  Future<void> createFolder(String path) async {
    _root.getChildAssumingFolder(path).create();
  }

  @override
  Future<void> deleteFileSystemEntity(String path) async {
    final file = _root.getChildAssumingFile(path);
    if (file.exists) {
      file.delete();
      return;
    }
    final folder = _root.getChildAssumingFolder(path);
    if (folder.exists) {
      folder.delete();
      return;
    }
  }

  @override
  Future<List<({String path, String type})>> listDirectory({required String path, bool recursive = false}) async {
    final folder = _root.getChildAssumingFolder(path);
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
      .ADD => FileAddedEvent(relativePath),
      .REMOVE => FileRemovedEvent(relativePath),
      .MODIFY || _ => FileModifiedEvent(relativePath),
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
  Future<bool> fileExist(String path) => _workspace.fileExist(path);

  @override
  Future<bool> folderExist(String path) => _workspace.folderExist(path);

  @override
  Future<String> readFileAsText(String path) => _workspace.readFileAsText(path);

  @override
  Future<Uint8List> readFileAsBytes(String path) => _workspace.readFileAsBytes(path);

  @override
  Future<void> writeFileFromText(String path, String content) => _workspace.writeFileFromText(path, content);

  @override
  Future<void> writeFileFromBytes(String path, Uint8List bytes) => _workspace.writeFileFromBytes(path, bytes);

  @override
  Future<void> createFolder(String path) => _workspace.createFolder(path);

  @override
  Future<void> deleteFileSystemEntity(String path) => _workspace.deleteFileSystemEntity(path);

  @override
  Future<List<({String path, String type})>> listDirectory({required String path, bool recursive = false}) =>
      _workspace.listDirectory(path, recursive: recursive);

  @override
  Stream<FileChangeEvent> get rawFileChanges => _workspaceWatcher.changes.expand((event) {
    final result = _mapEventToRelativePath(event);
    return [?result];
  });

  FileChangeEvent? _mapEventToRelativePath(FileChangeEvent event) {
    final relativePath = _relativePath(event.path);
    if (relativePath == null) {
      return null;
    }
    return switch (event) {
      FileAddedEvent() => FileAddedEvent(relativePath),
      FileRemovedEvent() => FileRemovedEvent(relativePath),
      FileModifiedEvent() => FileModifiedEvent(relativePath),
    };
  }

  String? _relativePath(String path) {
    final root = _workspace.workspaceFolder;
    if (!workspacePath.isAbsolute(path)) {
      return path;
    }
    if (!workspacePath.isWithin(root, path)) {
      return null;
    }
    return workspacePath.relative(path, from: root);
  }

  @override
  Future<void> get changeEventsReady => _workspaceWatcher.ready;

  @override
  Future<void> dispose() => _workspace.close();
}
