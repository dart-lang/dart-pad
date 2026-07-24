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
  const FileTreeNode(this.resource);

  /// The workspace resource represented by this node.
  final WorkspaceResource resource;
}

/// A file displayed in the workspace tree.
final class FileTreeFileNode extends FileTreeNode {
  /// Creates a file node for [resource].
  const FileTreeFileNode(
    WorkspaceFile super.resource, {
    required this.openable,
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
  ]) : children = List.unmodifiable(children);

  /// The immutable list of immediate child nodes.
  final List<FileTreeNode> children;
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
    required this.collapsedFolders,
    required this.selectedFolder,
    required this.dropTargetFolder,
    required this.draggedFile,
    required this.draggedFolder,
    required this.activeFile,
    required this.creatingEntry,
    required this.createTargetFolder,
    required this.newEntryName,
    required this.renamingFile,
    required this.renamingFolder,
    required this.renameValue,
    required this.nameValidationError,
    required this.operationError,
    required this.busy,
    required this.protectedEntries,
    required this.dirtyEntries,
  });

  /// The root node whose children are displayed in the tree.
  final FileTreeFolderNode root;

  /// Paths of folders whose children are hidden.
  final Set<String> collapsedFolders;

  /// The selected folder path, or `null` when no folder is selected.
  final String? selectedFolder;

  /// The folder currently highlighted as a drop target.
  final String? dropTargetFolder;

  /// The path of the file currently being dragged.
  final String? draggedFile;

  /// The path of the folder currently being dragged.
  final String? draggedFolder;

  /// The path displayed in the active editor tab.
  final String activeFile;

  /// The kind of entry currently being created, if any.
  final FileTreeEntryKind? creatingEntry;

  /// The folder in which the new entry will be created.
  final String createTargetFolder;

  /// The current value of the new-entry name input.
  final String newEntryName;

  /// The path of the file currently being renamed.
  final String? renamingFile;

  /// The path of the folder currently being renamed.
  final String? renamingFolder;

  /// The current value of the rename input.
  final String renameValue;

  /// The current name validation error, or `null` for a valid name.
  final String? nameValidationError;

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
    required this.setNewEntryName,
    required this.setRenameValue,
    required this.startAddingFile,
    required this.startAddingFolder,
    required this.handleCreateBlur,
    required this.confirmAddFile,
    required this.confirmAddFolder,
    required this.cancelCreate,
    required this.startRenamingFile,
    required this.startRenamingFolder,
    required this.confirmRenameFile,
    required this.confirmRenameFolder,
    required this.cancelRename,
    required this.selectFolder,
    required this.toggleFolder,
    required this.clearFolderSelection,
    required this.startDraggingFile,
    required this.startDraggingFolder,
    required this.finishDragging,
    required this.markDropTarget,
    required this.clearDropTarget,
    required this.dropIntoFolder,
    required this.openFile,
    required this.deleteFile,
    required this.deleteFolder,
  });

  /// Updates the proposed name for a new entry.
  final void Function(String) setNewEntryName;

  /// Updates the proposed name for the entry being renamed.
  final void Function(String) setRenameValue;

  /// Starts creating a file in the selected folder.
  final void Function() startAddingFile;

  /// Starts creating a folder in the selected folder.
  final void Function() startAddingFolder;

  /// Confirms or cancels creation when the new-entry input loses focus.
  final Future<void> Function() handleCreateBlur;

  /// Creates a file using the current new-entry name.
  final Future<void> Function() confirmAddFile;

  /// Creates a folder using the current new-entry name.
  final Future<void> Function() confirmAddFolder;

  /// Cancels entry creation.
  final void Function() cancelCreate;

  /// Starts renaming the file at the supplied path.
  final void Function(String) startRenamingFile;

  /// Starts renaming the folder at the supplied path.
  final void Function(String) startRenamingFolder;

  /// Renames the file at the supplied path using the current rename value.
  final Future<void> Function(String) confirmRenameFile;

  /// Renames the folder at the supplied path using the current rename value.
  final Future<void> Function(String) confirmRenameFolder;

  /// Cancels the active rename operation.
  final void Function() cancelRename;

  /// Selects the folder at the supplied path.
  final void Function(String) selectFolder;

  /// Selects the supplied folder and toggles whether it is collapsed.
  final void Function(String) toggleFolder;

  /// Clears the current folder selection.
  final void Function() clearFolderSelection;

  /// Starts dragging the file at the supplied path.
  final void Function(String) startDraggingFile;

  /// Starts dragging the folder at the supplied path.
  final void Function(String) startDraggingFolder;

  /// Clears the current drag-and-drop state.
  final void Function() finishDragging;

  /// Marks the supplied folder as the current drop target.
  final void Function(String) markDropTarget;

  /// Clears the supplied folder as a drop target.
  final void Function(String) clearDropTarget;

  /// Moves the dragged entry into the supplied folder.
  final Future<void> Function(String) dropIntoFolder;

  /// Opens the file at the supplied path.
  final FutureOr<void> Function(String) openFile;

  /// Deletes the file at the supplied path.
  final Future<void> Function(String) deleteFile;

  /// Deletes the folder at the supplied path and all of its contents.
  final Future<void> Function(String) deleteFolder;
}
