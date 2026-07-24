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
    _workspaceSubscription = workspace.watcher.events.listen(_handleWorkspaceEvent);
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
  static final RegExp _invalidCharacters = RegExp(r'[\x00-\x1f\x7f/\\]');

  /// The editor integration used to coordinate file operations with open tabs.
  final FileTreeEditorDelegate tabs;

  /// The workspace whose resources are displayed and mutated.
  final WorkspaceController workspace;

  /// The event bus used to report workspace operation failures.
  final AppEventBus events;

  FileTreeFolderNode _root;
  final Set<String> _collapsedFolders = {};
  StreamSubscription<WorkspaceChangeEvent>? _workspaceSubscription;
  Timer? _refreshDebounce;
  int _refreshGeneration = 0;
  bool _disposed = false;
  bool _busy = false;

  String? _selectedFolder;
  String? _dropTargetFolder;
  String? _draggedFile;
  String? _draggedFolder;
  FileTreeEntryKind? _creatingEntry;
  String _newEntryName = '';
  String? _renamingFile;
  String? _renamingFolder;
  String _renameValue = '';
  String? _nameValidationError;
  String? _operationError;

  /// The current immutable state consumed by the file-tree view.
  FileTreeState get state => FileTreeState(
    root: _root,
    collapsedFolders: Set.unmodifiable(_collapsedFolders),
    selectedFolder: _selectedFolder,
    dropTargetFolder: _dropTargetFolder,
    draggedFile: _draggedFile,
    draggedFolder: _draggedFolder,
    activeFile: tabs.activeFile,
    creatingEntry: _creatingEntry,
    createTargetFolder: _selectedFolder ?? '',
    newEntryName: _newEntryName,
    renamingFile: _renamingFile,
    renamingFolder: _renamingFolder,
    renameValue: _renameValue,
    nameValidationError: _nameValidationError,
    operationError: _operationError,
    busy: _busy,
    protectedEntries: _protectedEntries,
    dirtyEntries: Set.unmodifiable(_pathsWithAncestors(tabs.dirtyFiles)),
  );

  /// The actions that the file-tree view can invoke.
  FileTreeActions get actions => FileTreeActions(
    setNewEntryName: setNewEntryName,
    setRenameValue: setRenameValue,
    startAddingFile: startAddingFile,
    startAddingFolder: startAddingFolder,
    handleCreateBlur: handleCreateBlur,
    confirmAddFile: confirmAddFile,
    confirmAddFolder: confirmAddFolder,
    cancelCreate: cancelCreate,
    startRenamingFile: startRenamingFile,
    startRenamingFolder: startRenamingFolder,
    confirmRenameFile: confirmRenameFile,
    confirmRenameFolder: confirmRenameFolder,
    cancelRename: cancelRename,
    selectFolder: selectFolder,
    toggleFolder: toggleFolder,
    clearFolderSelection: clearFolderSelection,
    startDraggingFile: startDraggingFile,
    startDraggingFolder: startDraggingFolder,
    finishDragging: finishDragging,
    markDropTarget: markDropTarget,
    clearDropTarget: clearDropTarget,
    dropIntoFolder: dropIntoFolder,
    openFile: tabs.openTextFile,
    deleteFile: deleteFile,
    deleteFolder: deleteFolder,
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

  /// Updates and validates the proposed [value] for a new entry.
  void setNewEntryName(String value) {
    _newEntryName = value;
    _nameValidationError = value.isEmpty ? null : _validateName(value);
    _notify();
  }

  /// Updates and validates the proposed rename [value].
  void setRenameValue(String value) {
    _renameValue = value;
    _nameValidationError = value.isEmpty ? null : _validateName(value);
    _notify();
  }

  /// Starts creating a file in the selected folder.
  void startAddingFile() => _startAdding(FileTreeEntryKind.file);

  /// Starts creating a folder in the selected folder.
  void startAddingFolder() => _startAdding(FileTreeEntryKind.folder);

  void _startAdding(FileTreeEntryKind kind) {
    if (_busy) {
      return;
    }
    _creatingEntry = kind;
    _newEntryName = '';
    _nameValidationError = null;
    _operationError = null;
    _renamingFile = null;
    _renamingFolder = null;
    final selectedFolder = _selectedFolder;
    if (selectedFolder != null) {
      _collapsedFolders.remove(selectedFolder);
    }
    _notify();
  }

  /// Confirms a named entry or cancels an empty one when its input loses focus.
  Future<void> handleCreateBlur() async {
    if (_busy || _creatingEntry == null) {
      return;
    }
    if (_newEntryName.trim().isEmpty) {
      cancelCreate();
      return;
    }
    if (_creatingEntry == FileTreeEntryKind.folder) {
      await confirmAddFolder();
    } else if (_creatingEntry == FileTreeEntryKind.file) {
      await confirmAddFile();
    }
  }

  /// Creates a file using the current new-entry name.
  Future<void> confirmAddFile() => _createEntry(FileTreeEntryKind.file);

  /// Creates a folder using the current new-entry name.
  Future<void> confirmAddFolder() => _createEntry(FileTreeEntryKind.folder);

  Future<void> _createEntry(FileTreeEntryKind kind) async {
    final name = _validatedSubmittedName(_newEntryName);
    if (name == null) {
      return;
    }
    final parentPath = _selectedFolder ?? '';
    final targetPath = joinWorkspacePath(parentPath, name);

    await _runMutation(() async {
      await workspace.ensureTargetAvailable(
        sourcePath: '',
        targetPath: targetPath,
      );
      final parent = workspace.root.getFolder(parentPath);
      if (kind == FileTreeEntryKind.file) {
        await parent.getFile(name).writeContent('');
      } else {
        await parent.getFolder(name).create();
      }
      _creatingEntry = null;
      _newEntryName = '';
      if (kind == FileTreeEntryKind.folder) {
        _selectedFolder = targetPath;
        _collapsedFolders.remove(parentPath);
      }
      await refresh();
      if (kind == FileTreeEntryKind.file) {
        await tabs.openTextFile(targetPath);
      }
    });
  }

  /// Cancels the active entry-creation operation.
  void cancelCreate() {
    _creatingEntry = null;
    _newEntryName = '';
    _nameValidationError = null;
    _notify();
  }

  /// Starts renaming the file at [path] unless it is protected.
  void startRenamingFile(String path) {
    if (_busy || isProtectedFile(path)) {
      return;
    }
    _renamingFile = path;
    _renamingFolder = null;
    _renameValue = workspaceBasename(path);
    _creatingEntry = null;
    _nameValidationError = null;
    _operationError = null;
    _notify();
  }

  /// Starts renaming the folder at [path] unless it is protected.
  void startRenamingFolder(String path) {
    if (_busy || isProtectedFolder(path)) {
      return;
    }
    _renamingFolder = path;
    _renamingFile = null;
    _renameValue = workspaceBasename(path);
    _creatingEntry = null;
    _nameValidationError = null;
    _operationError = null;
    _notify();
  }

  /// Renames the file at [oldPath] using the current rename value.
  Future<void> confirmRenameFile(String oldPath) async {
    final newName = _validatedSubmittedName(_renameValue);
    if (newName == null) {
      return;
    }
    final newPath = joinWorkspacePath(workspaceDirname(oldPath), newName);
    if (newPath == oldPath) {
      cancelRename();
      return;
    }

    await _runMutation(() async {
      await _prepareRenameOrMove(oldPath, newPath);
      await workspace.root.getFile(oldPath).rename(newName);
      _renamingFile = null;
      _renameValue = '';
      await refresh();
    });
  }

  /// Renames the folder at [oldPath] using the current rename value.
  Future<void> confirmRenameFolder(String oldPath) async {
    final newName = _validatedSubmittedName(_renameValue);
    if (newName == null) {
      return;
    }
    final newPath = joinWorkspacePath(workspaceDirname(oldPath), newName);
    if (newPath == oldPath) {
      cancelRename();
      return;
    }

    await _runMutation(() async {
      await _prepareRenameOrMove(oldPath, newPath);
      await workspace.root.getFolder(oldPath).rename(newName);
      _rebaseFolderUiState(oldPath, newPath);
      _renamingFolder = null;
      _renameValue = '';
      await refresh();
    });
  }

  /// Cancels the active rename operation.
  void cancelRename() {
    _renamingFile = null;
    _renamingFolder = null;
    _renameValue = '';
    _nameValidationError = null;
    _notify();
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
      _collapsedFolders.removeWhere((entry) => isWithinWorkspaceFolder(entry, path));
      if (_selectedFolder case final selected? when isWithinWorkspaceFolder(selected, path)) {
        final parent = workspaceDirname(path);
        _selectedFolder = parent.isEmpty ? null : parent;
      }
      await refresh();
    });
  }

  /// Selects the folder at [path] as the target for new entries.
  void selectFolder(String path) {
    _selectedFolder = path;
    _notify();
  }

  /// Selects the folder at [path] and toggles its collapsed state.
  void toggleFolder(String path) {
    _selectedFolder = path;
    if (!_collapsedFolders.remove(path)) {
      _collapsedFolders.add(path);
    }
    _notify();
  }

  /// Clears the current folder selection.
  void clearFolderSelection() {
    _selectedFolder = null;
    _notify();
  }

  /// Starts dragging the file at [path] unless it is protected.
  void startDraggingFile(String path) {
    if (_busy || isProtectedFile(path)) {
      return;
    }
    _draggedFile = path;
    _draggedFolder = null;
    _notify();
  }

  /// Starts dragging the folder at [path] unless it is protected.
  void startDraggingFolder(String path) {
    if (_busy || isProtectedFolder(path)) {
      return;
    }
    _draggedFolder = path;
    _draggedFile = null;
    _notify();
  }

  /// Clears the current drag source and drop target.
  void finishDragging() {
    _draggedFile = null;
    _draggedFolder = null;
    _dropTargetFolder = null;
    _notify();
  }

  /// Marks [folder] as the current valid drop target.
  void markDropTarget(String folder) {
    if (_busy || (_draggedFile == null && _draggedFolder == null)) {
      return;
    }
    final draggedFolder = _draggedFolder;
    if (draggedFolder != null && !_canMoveFolder(draggedFolder, folder)) {
      return;
    }
    _dropTargetFolder = folder;
    _notify();
  }

  /// Clears [folder] as the drop target if it is currently marked.
  void clearDropTarget(String folder) {
    if (_dropTargetFolder == folder) {
      _dropTargetFolder = null;
      _notify();
    }
  }

  /// Moves the dragged file or folder into [targetFolderPath].
  Future<void> dropIntoFolder(String targetFolderPath) async {
    final filePath = _draggedFile;
    final folderPath = _draggedFolder;
    if (filePath == null && folderPath == null) {
      return;
    }

    await _runMutation(() async {
      final sourcePath = filePath ?? folderPath!;
      if (folderPath != null && !_canMoveFolder(folderPath, targetFolderPath)) {
        throw ArgumentError('A folder cannot be moved into itself.');
      }
      final newPath = joinWorkspacePath(targetFolderPath, workspaceBasename(sourcePath));
      if (newPath == sourcePath) {
        return;
      }
      await _prepareRenameOrMove(sourcePath, newPath);
      final targetFolder = workspace.root.getFolder(targetFolderPath);
      if (filePath != null) {
        await workspace.root.getFile(filePath).moveTo(targetFolder);
      } else {
        await workspace.root.getFolder(folderPath!).moveTo(targetFolder);
        _rebaseFolderUiState(folderPath, newPath);
      }
      _selectedFolder = targetFolderPath.isEmpty ? null : targetFolderPath;
      _collapsedFolders.remove(targetFolderPath);
      await refresh();
    });
    finishDragging();
  }

  Future<void> _prepareRenameOrMove(String oldPath, String newPath) async {
    await workspace.ensureTargetAvailable(
      sourcePath: oldPath,
      targetPath: newPath,
    );
    await tabs.saveAllTabs();
    try {
      await workspace.languageServerClient.willRenameFiles(oldPath, newPath);
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

  void _rebaseFolderUiState(String oldPath, String newPath) {
    final nextCollapsed = {
      for (final folder in _collapsedFolders)
        if (isWithinWorkspaceFolder(folder, oldPath)) rebaseWorkspacePath(folder, oldPath, newPath) else folder,
    };
    _collapsedFolders
      ..clear()
      ..addAll(nextCollapsed);
    final selected = _selectedFolder;
    if (selected != null && isWithinWorkspaceFolder(selected, oldPath)) {
      _selectedFolder = rebaseWorkspacePath(selected, oldPath, newPath);
    }
  }

  String? _validatedSubmittedName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _nameValidationError = 'A name is required.';
      _notify();
      return null;
    }
    final error = _validateName(value);
    if (error != null) {
      _nameValidationError = error;
      _notify();
      return null;
    }
    return trimmed;
  }

  static String? _validateName(String value) {
    if (value != value.trim()) {
      return 'Leading or trailing whitespace is not allowed.';
    }
    if (value == '.' || value == '..') {
      return '"$value" is not a valid workspace name.';
    }
    if (_invalidCharacters.hasMatch(value)) {
      return 'The name contains a path separator or control character.';
    }
    return null;
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
      if (!isVisibleWorkspacePath(resource.path)) {
        continue;
      }
      if (resource is WorkspaceFolder) {
        folders[resource.path] = resource;
      } else if (resource is WorkspaceFile) {
        children
            .putIfAbsent(resource.parent.path, () => [])
            .add(
              FileTreeFileNode(
                resource,
                openable: isEditableTextFile(resource.path),
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
      builtFolders[folderPath] = FileTreeFolderNode(folder, folderChildren);
    }

    final rootChildren = children[root.path] ?? <FileTreeNode>[];
    rootChildren.addAll(
      builtFolders.values.where((node) => node.resource.parent.path == root.path),
    );
    _sortNodes(rootChildren);
    return FileTreeFolderNode(root, rootChildren);
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
