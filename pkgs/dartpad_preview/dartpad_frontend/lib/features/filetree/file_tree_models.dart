// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// @docImport 'file_tree_view.dart';
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';

/// A file-system resource displayed in the workspace tree.
sealed class FileTreeNode {
  /// Creates a tree node for [resource].
  const FileTreeNode(this.resource, {this.isIgnored = false});

  /// The workspace resource represented by this node.
  final WorkspaceResource resource;

  /// Whether this node represents an ignored/hidden resource.
  final bool isIgnored;
}

/// A file displayed in the workspace tree.
final class FileTreeFileNode extends FileTreeNode {
  /// Creates a file node for [resource].
  const FileTreeFileNode(
    WorkspaceFile super.resource, {
    required this.openable,
    super.isIgnored = false,
  });

  /// Whether the file can be opened in the text editor.
  final bool openable;
}

/// A folder and its immediate [children] in the workspace tree.
final class FileTreeFolderNode extends FileTreeNode {
  /// Creates a folder node for [resource] containing [children].
  FileTreeFolderNode(
    WorkspaceFolder super.resource, [
    Iterable<FileTreeNode> children = const [],
    bool isIgnored = false,
  ]) : children = List.unmodifiable(children),
       super(isIgnored: isIgnored);

  /// The immutable list of immediate child nodes.
  final List<FileTreeNode> children;

  /// Recursively checks if a node exists in this subtree with the given [path].
  bool exists(String path) {
    if (resource.path == path) {
      return true;
    }
    for (final child in children) {
      if (child is FileTreeFolderNode) {
        if (child.exists(path)) {
          return true;
        }
      } else if (child.resource.path == path) {
        return true;
      }
    }
    return false;
  }

  /// Recursively checks if a folder exists in this subtree with the given [path].
  bool isFolder(String path) {
    if (resource.path == path) {
      return true;
    }
    for (final child in children) {
      if (child is FileTreeFolderNode) {
        if (child.isFolder(path)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// The kind of workspace entry being created.
enum FileTreeEntryKind {
  /// A workspace file.
  file,

  /// A workspace folder.
  folder,
}

/// An immutable snapshot of all state rendered by [FileTreeView].
final class FileTreeState {
  /// Creates a file-tree state snapshot.
  const FileTreeState({
    required this.root,
    required this.activeFile,
    required this.operationError,
    required this.busy,
    required this.protectedEntries,
    required this.dirtyEntries,
  });

  /// The root node whose children are displayed in the tree.
  final FileTreeFolderNode root;

  /// The path displayed in the active editor tab.
  final String activeFile;

  /// The latest user-facing workspace operation error.
  final String? operationError;

  /// Whether a workspace mutation is in progress.
  final bool busy;

  /// Paths that cannot be renamed, moved, or deleted.
  final Set<String> protectedEntries;

  /// File and ancestor folder paths containing unsaved changes.
  final Set<String> dirtyEntries;
}

/// User actions exposed by the file-tree view model.
final class FileTreeActions {
  /// Creates the action bundle consumed by [FileTreeView].
  const FileTreeActions({
    required this.createFile,
    required this.createFolder,
    required this.renameFile,
    required this.renameFolder,
    required this.deleteFile,
    required this.deleteFolder,
    required this.moveEntry,
    required this.openFile,
    required this.clearOperationError,
  });

  /// Creates a file in the selected folder.
  final Future<void> Function(String parentPath, String name) createFile;

  /// Creates a folder in the selected folder.
  final Future<void> Function(String parentPath, String name) createFolder;

  /// Renames the file at the supplied path.
  final Future<void> Function(String path, String newName) renameFile;

  /// Renames the folder at the supplied path.
  final Future<void> Function(String path, String newName) renameFolder;

  /// Deletes the file at the supplied path.
  final Future<void> Function(String path) deleteFile;

  /// Deletes the folder at the supplied path and all of its contents.
  final Future<void> Function(String path) deleteFolder;

  /// Moves the entry into the target folder.
  final Future<void> Function(String sourcePath, String targetFolderPath) moveEntry;

  /// Opens the file at the supplied path.
  final FutureOr<void> Function(String path) openFile;

  /// Clears the current operation error.
  final void Function() clearOperationError;
}
