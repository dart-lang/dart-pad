// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import '../shared/app_event_bus.dart';
import '../shared/editable_text_file.dart';
import '../shared/events/log_event.dart';
import '../shared/user_facing_errors.dart';
import '../shared/workspace_paths.dart';
import 'file_tree_editor_delegate.dart';
import 'file_tree_models.dart';

/// Owns all mutable file-tree state and workspace mutations.
final class FileTreeViewModel extends ChangeNotifier {
  /// Creates a file-tree model for [workspace] and starts loading its entries.
  FileTreeViewModel({
    required this.tabs,
    required this.workspace,
    required this.events,
  }) : _root = FileTreeFolderNode(workspace.root) {
    tabs.addListener(_handleTabsChanged);
    _workspaceSubscription = workspace.changeEvents.listen(_handleWorkspaceEvent);
    unawaited(refresh());
  }

  /// Project files that must remain available for DartPad Preview to run.
  static const Set<String> protectedPaths = {
    'lib/main.dart',
    'pubspec.yaml',
  };
  static final Set<String> _protectedEntries = Set.unmodifiable(
    _pathsWithAncestors(protectedPaths),
  );

  /// The editor integration used to coordinate file operations with open tabs.
  final FileTreeEditorDelegate tabs;

  /// The workspace whose resources are displayed and mutated.
  final WorkspaceResourceApi workspace;

  /// The event bus used to report workspace operation failures.
  final AppEventBus events;

  /// The language server client used to coordinate file rename refactorings.
  LanguageServerClient? languageServerClient;

  FileTreeFolderNode _root;
  StreamSubscription<WorkspaceChangeEvent>? _workspaceSubscription;
  Timer? _refreshDebounce;
  int _refreshGeneration = 0;
  bool _disposed = false;
  bool _busy = false;
  String? _operationError;

  /// The current immutable state consumed by the file-tree view.
  FileTreeState get state => FileTreeState(
    root: _root,
    activeFile: tabs.activeFile,
    operationError: _operationError,
    busy: _busy,
    protectedEntries: _protectedEntries,
    dirtyEntries: Set.unmodifiable(_pathsWithAncestors(tabs.dirtyFiles)),
  );

  /// The actions that the file-tree view can invoke.
  FileTreeActions get actions => FileTreeActions(
    createFile: createFile,
    createFolder: createFolder,
    renameFile: renameFile,
    renameFolder: renameFolder,
    deleteFile: deleteFile,
    deleteFolder: deleteFolder,
    moveEntry: moveEntry,
    openFile: tabs.openTextFile,
    clearOperationError: clearOperationError,
  );

  /// Whether the file at [path] is required by DartPad Preview.
  bool isProtectedFile(String path) => protectedPaths.contains(normalizeWorkspacePath(path));

  /// Whether [path] is or contains a file required by DartPad Preview.
  bool isProtectedFolder(String path) {
    final normalized = normalizeWorkspacePath(path);
    return protectedPaths.any((protectedPath) => isWithinWorkspaceFolder(protectedPath, normalized));
  }

  /// Whether [path] has unsaved changes.
  ///
  /// When [folder] is true, descendants of [path] are checked as well.
  bool hasDirtyEntry(String path, {required bool folder}) {
    final normalized = normalizeWorkspacePath(path);
    return tabs.dirtyFiles.any(
      (dirtyPath) => folder ? isWithinWorkspaceFolder(dirtyPath, normalized) : dirtyPath == normalized,
    );
  }

  /// Creates a file in the target folder.
  Future<void> createFile(String parentPath, String name) async {
    final targetPath = joinWorkspacePath(parentPath, name);
    await _runMutation(() async {
      await workspace.ensureTargetAvailable(
        sourcePath: '',
        targetPath: targetPath,
      );
      final parent = workspace.root.getFolder(parentPath);
      await parent.getFile(name).writeContent('');
      await refresh();
      await tabs.openTextFile(targetPath);
    });
  }

  /// Creates a folder in the target folder.
  Future<void> createFolder(String parentPath, String name) async {
    final targetPath = joinWorkspacePath(parentPath, name);
    await _runMutation(() async {
      await workspace.ensureTargetAvailable(
        sourcePath: '',
        targetPath: targetPath,
      );
      final parent = workspace.root.getFolder(parentPath);
      await parent.getFolder(name).create();
      await refresh();
    });
  }

  /// Renames the file at [oldPath].
  Future<void> renameFile(String oldPath, String newName) async {
    final newPath = joinWorkspacePath(workspaceDirname(oldPath), newName);
    if (newPath == oldPath) {
      return;
    }

    await _runMutation(() async {
      await _prepareRenameOrMove(oldPath, newPath);
      await workspace.root.getFile(oldPath).rename(newName);
      await refresh();
    });
  }

  /// Renames the folder at [oldPath].
  Future<void> renameFolder(String oldPath, String newName) async {
    final newPath = joinWorkspacePath(workspaceDirname(oldPath), newName);
    if (newPath == oldPath) {
      return;
    }

    await _runMutation(() async {
      await _prepareRenameOrMove(oldPath, newPath);
      await workspace.root.getFolder(oldPath).rename(newName);
      await refresh();
    });
  }

  /// Deletes the file at [path] unless it is protected.
  Future<void> deleteFile(String path) async {
    if (isProtectedFile(path)) {
      _setOperationError('$path is required by DartPad Preview and cannot be deleted.');
      return;
    }
    await _runMutation(() async {
      final file = workspace.root.getFile(path);
      if (await file.exists()) {
        await file.delete();
      }
      await refresh();
    });
  }

  /// Deletes the folder at [path] and its contents unless it is protected.
  Future<void> deleteFolder(String path) async {
    if (isProtectedFolder(path)) {
      _setOperationError('$path contains a required project file and cannot be deleted.');
      return;
    }
    await _runMutation(() async {
      final folder = workspace.root.getFolder(path);
      if (await folder.exists()) {
        await folder.delete();
      }
      await refresh();
    });
  }

  /// Moves the entry into [targetFolderPath].
  Future<void> moveEntry(String sourcePath, String targetFolderPath) async {
    final isFolder = await workspace.folderExist(sourcePath);
    if (isFolder && !_canMoveFolder(sourcePath, targetFolderPath)) {
      throw ArgumentError('A folder cannot be moved into itself.');
    }
    final newPath = joinWorkspacePath(targetFolderPath, workspaceBasename(sourcePath));
    if (newPath == sourcePath) {
      return;
    }

    await _runMutation(() async {
      await _prepareRenameOrMove(sourcePath, newPath);
      final targetFolder = workspace.root.getFolder(targetFolderPath);
      if (!isFolder) {
        await workspace.root.getFile(sourcePath).moveTo(targetFolder);
      } else {
        await workspace.root.getFolder(sourcePath).moveTo(targetFolder);
      }
      await refresh();
    });
  }

  Future<void> _prepareRenameOrMove(String oldPath, String newPath) async {
    await workspace.ensureTargetAvailable(
      sourcePath: oldPath,
      targetPath: newPath,
    );
    await tabs.saveAllTabs();
    try {
      if (languageServerClient case final lsp?) {
        await lsp.willRenameFiles(oldPath, newPath);
      }
    } catch (error, stackTrace) {
      if (!_isWillRenameResponseError(error)) {
        rethrow;
      }
      const message = 'Imports could not be updated automatically; continuing with the move.';
      tabs.reportWarning(message);
      events.dispatch(
        LogEvent(
          message,
          level: Level.WARNING,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  bool _isWillRenameResponseError(Object error) {
    return error is StateError && error.toString().contains('workspace/willRenameFiles failed:');
  }

  bool _canMoveFolder(String folder, String targetFolder) {
    final source = normalizeWorkspacePath(folder);
    final target = normalizeWorkspacePath(targetFolder);
    return source.isNotEmpty && !isWithinWorkspaceFolder(target, source);
  }

  void clearOperationError() {
    _operationError = null;
    _notify();
  }

  Future<void> _runMutation(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    _busy = true;
    _operationError = null;
    tabs.clearMessages();
    _notify();
    try {
      await operation();
    } catch (error, stackTrace) {
      _setOperationError(
        userFacingErrorMessage(
          error,
          fallback: 'Workspace operation failed.',
        ),
      );
      events.dispatch(
        LogEvent(
          'Workspace operation failed.',
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reloads the visible file-tree structure from the workspace.
  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    final resources = await workspace.root.getChildren(recursive: true);
    final tree = _buildTree(workspace.root, resources);
    if (_disposed || generation != _refreshGeneration) {
      return;
    }
    _root = tree;
    _notify();
  }

  FileTreeFolderNode _buildTree(
    WorkspaceFolder root,
    List<WorkspaceResource> resources,
  ) {
    final folders = <String, WorkspaceFolder>{root.path: root};
    final children = <String, List<FileTreeNode>>{};

    for (final resource in resources) {
      if (resource is WorkspaceFolder) {
        folders[resource.path] = resource;
      } else if (resource is WorkspaceFile) {
        final isIgnored = !isVisibleWorkspacePath(resource.path);
        children
            .putIfAbsent(resource.parent.path, () => [])
            .add(
              FileTreeFileNode(
                resource,
                openable: isEditableTextFile(resource.path),
                isIgnored: isIgnored,
              ),
            );
      }
    }

    final folderPaths = folders.keys.where((path) => path.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final builtFolders = <String, FileTreeFolderNode>{};
    for (final folderPath in folderPaths) {
      final folder = folders[folderPath]!;
      final folderChildren = children[folderPath] ?? <FileTreeNode>[];
      folderChildren.addAll(
        builtFolders.values.where((node) => node.resource.parent.path == folderPath),
      );
      _sortNodes(folderChildren);
      builtFolders[folderPath] = FileTreeFolderNode(
        folder,
        children: folderChildren,
        isIgnored: !isVisibleWorkspacePath(folderPath),
      );
    }

    final rootChildren = children[root.path] ?? <FileTreeNode>[];
    rootChildren.addAll(
      builtFolders.values.where((node) => node.resource.parent.path == root.path),
    );
    _sortNodes(rootChildren);
    return FileTreeFolderNode(root, children: rootChildren, isIgnored: !isVisibleWorkspacePath(root.path));
  }

  void _sortNodes(List<FileTreeNode> nodes) {
    nodes.sort((left, right) {
      if (left is FileTreeFolderNode && right is FileTreeFileNode) {
        return -1;
      }
      if (left is FileTreeFileNode && right is FileTreeFolderNode) {
        return 1;
      }
      return left.resource.shortName.compareTo(right.resource.shortName);
    });
  }

  void _handleWorkspaceEvent(WorkspaceChangeEvent event) {
    if (event.type == WorkspaceChangeEventType.modify) {
      return;
    }
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 50), () {
      unawaited(refresh());
    });
  }

  void _handleTabsChanged() => _notify();

  void _setOperationError(String message) {
    _operationError = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _refreshDebounce?.cancel();
    tabs.removeListener(_handleTabsChanged);
    unawaited(_workspaceSubscription?.cancel());
    _workspaceSubscription = null;
    super.dispose();
  }
}

Set<String> _pathsWithAncestors(Iterable<String> paths) {
  final result = <String>{};
  for (final path in paths) {
    var current = normalizeWorkspacePath(path);
    while (current.isNotEmpty) {
      result.add(current);
      current = workspaceDirname(current);
    }
  }
  return result;
}
