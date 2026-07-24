// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'workspace_path.dart';

abstract interface class WorkspaceApi {
  int get id;
  Uri get workspaceFolder;
  Future<bool> fileExist(String uri);
  Future<bool> folderExist(String uri);
  Future<String> readFileAsText(String uri);
  Future<Uint8List> readFileAsBytes(String uri);
  Future<void> writeFileFromText(String uri, String content);
  Future<void> writeFileFromBytes(String uri, Uint8List bytes);
  Future<void> createFolder(String uri);
  Future<void> deleteFileSystemEntity(String uri);
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false});
  void addMoveIntention(String oldPath, String newPath);
}

/// Thrown when a rename or move would overwrite an existing workspace entry.
final class WorkspaceResourceConflictException implements Exception {
  const WorkspaceResourceConflictException({
    required this.sourcePath,
    required this.targetPath,
  });

  final String sourcePath;
  final String targetPath;

  @override
  String toString() => 'Cannot move "$sourcePath" to "$targetPath": the target already exists.';
}

/// Adds shared validation for workspace operations that must not overwrite an
/// existing file or folder.
extension WorkspaceConflictValidation on WorkspaceApi {
  /// Throws a [WorkspaceResourceConflictException] when [targetPath] already
  /// exists as either a file or folder.
  Future<void> ensureTargetAvailable({
    required String sourcePath,
    required String targetPath,
  }) async {
    if (targetPath == sourcePath) {
      return;
    }
    if (await fileExist(targetPath) || await folderExist(targetPath)) {
      throw WorkspaceResourceConflictException(
        sourcePath: sourcePath,
        targetPath: targetPath,
      );
    }
  }
}

/// An abstraction of a file or folder in the workspace.
///
/// Provides a unified interface for querying, renaming, moving, and deleting
/// filesystem resources in the workspace.
sealed class WorkspaceResource {
  const WorkspaceResource({
    required this.workspace,
  });

  /// The underlying [WorkspaceApi] this resource belongs to.
  final WorkspaceApi workspace;

  /// Return the [WorkspaceFolder] that contains this resource, possibly itself if this
  /// resource is a root folder.
  WorkspaceFolder get parent;

  /// Return the full path to this resource.
  String get path;

  /// Return a short version of the name that can be displayed to the user to
  /// denote this resource.
  String get shortName;

  /// Check if the resource exists.
  Future<bool> exists();

  /// Rename this resource within its current parent folder.
  ///
  /// Registers a move intention with [WorkspaceApi.addMoveIntention], reads/writes
  /// the resource content,
  /// and deletes the old resource.
  Future<WorkspaceResource> rename(String newName);

  /// Move this resource to a new parent folder [targetFolder].
  ///
  /// Registers a move intention with [WorkspaceApi.addMoveIntention], reads/writes
  /// the resource content
  /// at the target destination, and deletes the old resource.
  Future<WorkspaceResource> moveTo(WorkspaceFolder targetFolder);

  /// Deletes this resource and its children.
  ///
  /// Throws an exception if the resource cannot be deleted.
  Future<void> delete();
}

/// A file inside the workspace.
class WorkspaceFile extends WorkspaceResource {
  WorkspaceFile({required super.workspace, required this.path});

  @override
  final String path;

  @override
  String get shortName => workspacePath.basename(path);

  @override
  WorkspaceFolder get parent => WorkspaceFolder(workspace: workspace, path: workspacePath.dirname(path));

  @override
  Future<bool> exists() {
    return workspace.fileExist(path);
  }

  /// Reads the file content as a UTF-8 text string.
  Future<String> readContent() {
    return workspace.readFileAsText(path);
  }

  /// Writes [content] to the file as a UTF-8 text string.
  Future<void> writeContent(String content) {
    return workspace.writeFileFromText(path, content);
  }

  @override
  Future<WorkspaceFile> rename(String newName) async {
    final newPath = workspacePath.canonicalize(workspacePath.join(workspacePath.dirname(path), newName));
    if (newPath == path) {
      return this;
    }
    await workspace.ensureTargetAvailable(
      sourcePath: path,
      targetPath: newPath,
    );

    workspace.addMoveIntention(path, newPath);

    final bytes = await workspace.readFileAsBytes(path);
    final newFile = WorkspaceFile(workspace: workspace, path: newPath);
    await workspace.writeFileFromBytes(newPath, bytes);
    await delete();
    return newFile;
  }

  @override
  Future<WorkspaceFile> moveTo(WorkspaceFolder targetFolder) async {
    final newPath = workspacePath.canonicalize(workspacePath.join(targetFolder.path, shortName));
    if (newPath == path) {
      return this;
    }
    await workspace.ensureTargetAvailable(
      sourcePath: path,
      targetPath: newPath,
    );

    workspace.addMoveIntention(path, newPath);

    final bytes = await workspace.readFileAsBytes(path);
    final newFile = WorkspaceFile(workspace: workspace, path: newPath);
    await workspace.writeFileFromBytes(newPath, bytes);
    await delete();
    return newFile;
  }

  @override
  Future<void> delete() {
    return workspace.deleteFileSystemEntity(path);
  }

  @override
  String toString() => 'WorkspaceFile(path: $path)';
}

/// A folder in the workspace that may contain files and/or other folders.
class WorkspaceFolder extends WorkspaceResource {
  WorkspaceFolder({required super.workspace, required String path}) : path = path == '.' ? '' : path;

  @override
  final String path;

  @override
  String get shortName => workspacePath.basename(path);

  /// Return `true` if this folder is a file system root.
  bool get isRoot => path.isEmpty;

  @override
  WorkspaceFolder get parent {
    if (isRoot) {
      return this;
    }
    return WorkspaceFolder(workspace: workspace, path: workspacePath.dirname(path));
  }

  @override
  Future<bool> exists() {
    return workspace.folderExist(path);
  }

  /// If this folder does not already exist, create it.
  Future<void> create() {
    return workspace.createFolder(path);
  }

  /// Return a [WorkspaceFile] representing the file with the given [relPath].
  ///
  /// This call does not check whether a file with the given name
  /// exists on the filesystem - client must call the [WorkspaceFile]'s `exists()` method
  /// to determine whether the file actually exists.
  WorkspaceFile getFile(String relPath) {
    return WorkspaceFile(workspace: workspace, path: workspacePath.join(path, relPath));
  }

  /// Return a [WorkspaceFolder] representing a the child folder at [relPath].
  ///
  /// This call does not check whether a folder with the given name
  /// exists on the filesystem--client must call the [WorkspaceFolder]'s `exists()` method
  /// to determine whether the folder actually exists.
  WorkspaceFolder getFolder(String relPath) {
    return WorkspaceFolder(workspace: workspace, path: workspacePath.join(path, relPath));
  }

  /// Return a list of existing children [WorkspaceResource]s (folders and files)
  /// in this folder, in no particular order.
  Future<List<WorkspaceResource>> getChildren({bool recursive = false}) async {
    final result = await workspace.listDirectory(uri: path, recursive: recursive);
    return [
      for (final r in result)
        switch (r.type) {
          'file' => getFile(r.path),
          'folder' => getFolder(r.path),
          _ => throw UnimplementedError('Unknown resource type: ${r.type}'),
        },
    ];
  }

  @override
  Future<WorkspaceFolder> rename(String newName) async {
    if (isRoot) {
      throw StateError('The workspace root cannot be renamed.');
    }
    final newPath = workspacePath.canonicalize(workspacePath.join(workspacePath.dirname(path), newName));
    if (newPath == path) {
      return this;
    }
    await _ensureMoveIsSafe(newPath);
    return await _moveFolderContents(newPath);
  }

  @override
  Future<WorkspaceFolder> moveTo(WorkspaceFolder targetFolder) async {
    if (isRoot) {
      throw StateError('The workspace root cannot be moved.');
    }
    final newPath = workspacePath.join(targetFolder.path, shortName);
    if (newPath == path) {
      return this;
    }
    await _ensureMoveIsSafe(newPath);
    return await _moveFolderContents(newPath);
  }

  Future<void> _ensureMoveIsSafe(String newPath) async {
    final normalizedSource = workspacePath.canonicalize(path);
    final normalizedTarget = workspacePath.canonicalize(newPath);
    if (workspacePath.isWithin(normalizedSource, normalizedTarget)) {
      throw ArgumentError.value(newPath, 'newPath', 'A folder cannot be moved into itself.');
    }
    await workspace.ensureTargetAvailable(
      sourcePath: path,
      targetPath: normalizedTarget,
    );
  }

  /// Recursively moves folder contents from the current folder to [newPath].
  ///
  /// This iterates over all child resources, creates corresponding folders
  /// at the target path, copies file contents (using bytes), registers move
  /// intentions with [WorkspaceApi.addMoveIntention], and recursively deletes the
  /// old folder structure.
  Future<WorkspaceFolder> _moveFolderContents(String newPath) async {
    // Register the intention for the folder itself
    workspace.addMoveIntention(path, newPath);

    final newFolder = WorkspaceFolder(workspace: workspace, path: newPath);
    await newFolder.create();

    final children = await getChildren(recursive: true);
    // Sort child paths by length so parent folders are created/handled before sub-entities
    children.sort((a, b) => a.path.length.compareTo(b.path.length));

    for (final child in children) {
      final targetPath = workspacePath.join(newPath, workspacePath.relative(child.path, from: path));
      workspace.addMoveIntention(child.path, targetPath);
      if (child is WorkspaceFolder) {
        await WorkspaceFolder(workspace: workspace, path: targetPath).create();
      } else if (child is WorkspaceFile) {
        final bytes = await workspace.readFileAsBytes(child.path);
        await workspace.writeFileFromBytes(targetPath, bytes);
      }
    }

    // Clean up the original folder (which deletes all its files and folders recursively)
    await delete();
    return newFolder;
  }

  @override
  Future<void> delete() {
    return workspace.deleteFileSystemEntity(path);
  }

  @override
  String toString() => 'WorkspaceFolder(path: $path)';
}
