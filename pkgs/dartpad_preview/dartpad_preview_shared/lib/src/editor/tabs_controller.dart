// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:path/path.dart' as p;

import '../lsp/language_server_client.dart';
import '../workspace/workspace_controller.dart';
import '../workspace/workspace_watcher.dart';
import 'editor_tab.dart';

final p.Context _workspacePath = p.posix;

/// A mixin class that controls the state of open editor tabs.
///
/// It manages opening, switching, saving, closing, and updating files within the editor workspace.
/// [T] represents the type of the tab's underlying editor view or content.
abstract mixin class TabsController<T> {
  /// Initializes the tabs controller with a [workspaceController] and a list of tab [adapters].
  ///
  /// Must be called in the constructor of the implementing class.
  void init({required WorkspaceController workspaceController, required List<EditorTabAdapter<T>> adapters}) {
    this.workspaceController = workspaceController;
    this.adapters = adapters;
    _workspaceSubscription = workspaceController.watcher.events.listen(_handleWorkspaceEvent);
    workspaceController.languageServerClient.setDisplayFileHandler(_handleDisplayFile);

    for (final adapter in adapters) {
      adapter.register(this);
    }
  }

  late final WorkspaceController workspaceController;
  late final List<EditorTabAdapter<T>> adapters;

  bool _disposed = false;

  final List<EditorTab<T>> _tabs = [];
  final Map<String, EditorTab<T>> _keepAliveTabs = {};
  final Map<String, Future<void>> _loadingTabs = {};
  final Map<String, StreamSubscription<void>> _tabUpdateSubscriptions = {};
  String _activeTabPath = '';
  StreamSubscription<WorkspaceChangeEvent>? _workspaceSubscription;

  Iterable<EditorTab<T>> get _allTabs => _tabs.followedBy(_keepAliveTabs.values);

  /// A read-only list of all currently open tabs.
  List<EditorTab<T>> get openTabs => List.unmodifiable(_tabs);

  /// The currently active tab, or `null` if no tab is active.
  EditorTab<T>? get activeTab {
    for (final t in _tabs) {
      if (t.path == _activeTabPath) {
        return t;
      }
    }
    return null;
  }

  /// The path of the currently active file (tab).
  String get activeFile => _activeTabPath;

  /// Whether any open tab has unsaved changes.
  bool get hasUnsavedChanges => _allTabs.any((t) => t.hasUnsavedChanges);

  /// Returns the paths of all files that currently have unsaved changes.
  List<String> get dirtyFiles => [
    for (final t in _allTabs)
      if (t.hasUnsavedChanges) t.path,
  ];

  /// Retrieves a tab by its file [path] if it's currently open or kept alive.
  EditorTab<T>? getTab(String path) {
    return _tabs.where((t) => t.path == path).firstOrNull ?? _keepAliveTabs[path];
  }

  /// Opens a file by its [fileName] (path).
  ///
  /// If the file is already open, it is set active. If it was closed but kept alive, it is restored.
  /// Otherwise, it uses the first compatible adapter to load and create a new tab.
  Future<void> openFile(String fileName) async {
    if (_disposed) {
      throw StateError('Cannot open a file on a disposed TabsController.');
    }
    if (!await workspaceController.root.getFile(fileName).exists()) {
      return;
    }

    final existingIndex = _tabs.indexWhere((t) => t.path == fileName);
    if (existingIndex != -1) {
      _setActivePath(fileName);
      return;
    }

    final keptTab = _keepAliveTabs.remove(fileName);
    if (keptTab != null) {
      _tabs.add(keptTab);
      _setActivePath(fileName);
      return;
    }

    Future<void>? loadFuture = _loadingTabs[fileName];
    if (loadFuture == null) {
      loadFuture = _loadTab(fileName);
      _loadingTabs[fileName] = loadFuture;
    }

    await loadFuture;
    if (_tabs.any((tab) => tab.path == fileName)) {
      _setActivePath(fileName);
    }
  }

  Future<void> _loadTab(String fileName) async {
    try {
      final tab = await _createTab(fileName);
      // Check if it got cancelled or deleted while loading
      if (!_loadingTabs.containsKey(fileName)) {
        tab.dispose();
        await _tabUpdateSubscriptions.remove(fileName)?.cancel();
        return;
      }

      if (!_tabs.any((t) => t.path == fileName)) {
        _tabs.add(tab);
      }
    } finally {
      unawaited(_loadingTabs.remove(fileName));
    }
  }

  Future<EditorTab<T>> _createTab(String fileName) async {
    for (final adapter in adapters) {
      final tab = await adapter.createTab(fileName);
      if (tab != null) {
        unawaited(_tabUpdateSubscriptions[fileName]?.cancel());
        _tabUpdateSubscriptions[fileName] = tab.onUpdate.listen((_) {
          didUpdate();
        });
        return tab;
      }
    }
    throw UnsupportedError('No editor tab adapter found for $fileName');
  }

  /// Switches the active file/tab to [fileName] if it is currently open.
  void switchFile(String fileName) {
    if (!_tabs.any((t) => t.path == fileName) || _activeTabPath == fileName) {
      return;
    }
    _setActivePath(fileName);
  }

  /// Saves the tab associated with [fileName] if it is open and has unsaved changes.
  Future<void> saveTab(String fileName) async {
    final tabIndex = _tabs.indexWhere((t) => t.path == fileName);
    if (tabIndex == -1) {
      return;
    }

    final tab = _tabs[tabIndex];
    if (!tab.hasUnsavedChanges) {
      return;
    }

    didUpdate(isSaving: true);
    try {
      await tab.save();
      await didSaveTabs([fileName]);
    } finally {
      didUpdate(isSaving: false);
    }
  }

  /// Saves all open tabs that have unsaved changes.
  Future<void> saveAllTabs() async {
    final savedFiles = <String>[];
    for (final tab in _allTabs) {
      if (tab.hasUnsavedChanges) {
        savedFiles.add(tab.path);
      }
    }
    if (savedFiles.isEmpty) {
      return;
    }

    didUpdate(isSaving: true);
    try {
      for (final tab in _allTabs.toList()) {
        if (tab.hasUnsavedChanges) {
          await tab.save();
        }
      }
      await didSaveTabs(savedFiles);
    } finally {
      didUpdate(isSaving: false);
    }
  }

  /// Closes the tab associated with [fileName].
  ///
  /// If the tab is configured as `keepAlive`, it will be kept in memory instead of being disposed.
  void closeTab(String fileName) {
    final tabIndex = _tabs.indexWhere((t) => t.path == fileName);
    if (tabIndex == -1 || _tabs.length <= 1) {
      return;
    }

    final tab = _tabs[tabIndex];
    final wasActive = fileName == _activeTabPath;
    final nextFile = wasActive ? _tabs[tabIndex + 1 < _tabs.length ? tabIndex + 1 : tabIndex - 1].path : null;

    if (wasActive) {
      tab.onDeactivate();
    }
    tab.onClose();

    _tabs.removeAt(tabIndex);

    if (tab.keepAlive) {
      _keepAliveTabs[fileName] = tab;
    } else {
      tab.dispose();
      _tabUpdateSubscriptions.remove(fileName)?.cancel();
    }

    if (nextFile != null) {
      _setActivePath(nextFile);
    } else {
      didUpdate();
    }
  }

  void _setActivePath(String path) {
    if (_activeTabPath == path) {
      return;
    }

    final oldActiveTab = activeTab;
    if (oldActiveTab != null) {
      oldActiveTab.onDeactivate();
    }

    _activeTabPath = path;

    final newActiveTab = activeTab;
    if (newActiveTab != null) {
      newActiveTab.onActivate();
    }

    didUpdate();
  }

  /// Reverts all editors with unsaved changes to their last saved content.
  void discardUnsavedChanges() {
    final dirtyTabs = _allTabs.where((tab) => tab.hasUnsavedChanges).toList();
    for (final tab in dirtyTabs) {
      tab.discardUnsavedChanges();
    }
    didUpdate();
  }

  Future<void> _handleDisplayFile(String uri) async {
    final folderPath = workspaceController.workspaceUri.path;
    final relativePath = LanguageServerClient.getRelativePath(uri, folderPath);
    await openFile(relativePath);
  }

  void _handleWorkspaceEvent(WorkspaceChangeEvent event) {
    if (event.type == WorkspaceChangeEventType.move) {
      _handleFileMoved(event.oldPath!, event.path);
    } else if (event.type == WorkspaceChangeEventType.remove) {
      _handleDeletedFile(event.path);
    }
  }

  void _handleFileMoved(String oldPath, String newPath) {
    final normalizedOldPath = _normalizeWorkspacePath(oldPath);
    final normalizedNewPath = _normalizeWorkspacePath(newPath);
    _cancelLoadsAtOrBelow(normalizedOldPath);

    final openTabs = _tabs.where((tab) => _isPathAtOrBelow(tab.path, normalizedOldPath)).toList();
    final keptTabs = _keepAliveTabs.entries.where((entry) => _isPathAtOrBelow(entry.key, normalizedOldPath)).toList();
    if (openTabs.isEmpty && keptTabs.isEmpty) {
      return;
    }

    for (final tab in openTabs) {
      final previousPath = tab.path;
      final rebasedPath = _rebaseWorkspacePath(
        previousPath,
        normalizedOldPath,
        normalizedNewPath,
      );
      tab.rename(rebasedPath);
      _moveTabUpdateSubscription(previousPath, rebasedPath);
    }
    for (final entry in keptTabs) {
      final previousPath = entry.key;
      final rebasedPath = _rebaseWorkspacePath(
        previousPath,
        normalizedOldPath,
        normalizedNewPath,
      );
      _keepAliveTabs.remove(previousPath);
      entry.value.rename(rebasedPath);
      _moveTabUpdateSubscription(previousPath, rebasedPath);
      _keepAliveTabs[rebasedPath] = entry.value;
    }
    if (_isPathAtOrBelow(_activeTabPath, normalizedOldPath)) {
      _activeTabPath = _rebaseWorkspacePath(
        _activeTabPath,
        normalizedOldPath,
        normalizedNewPath,
      );
    }
    didUpdate();
  }

  void _moveTabUpdateSubscription(String oldPath, String newPath) {
    final subscription = _tabUpdateSubscriptions.remove(oldPath);
    if (subscription == null) {
      return;
    }
    unawaited(_tabUpdateSubscriptions.remove(newPath)?.cancel());
    _tabUpdateSubscriptions[newPath] = subscription;
  }

  void _handleDeletedFile(String path) {
    final normalizedPath = _normalizeWorkspacePath(path);
    _cancelLoadsAtOrBelow(normalizedPath);

    final openTabs = _tabs.where((tab) => _isPathAtOrBelow(tab.path, normalizedPath)).toList();
    final keptTabs = _keepAliveTabs.entries.where((entry) => _isPathAtOrBelow(entry.key, normalizedPath)).toList();
    if (openTabs.isEmpty && keptTabs.isEmpty) {
      return;
    }

    final activeIndex = _tabs.indexWhere((tab) => tab.path == _activeTabPath);
    final activeWasDeleted = activeIndex != -1 && _isPathAtOrBelow(_activeTabPath, normalizedPath);
    String? nextActivePath;
    if (activeWasDeleted) {
      for (var index = activeIndex + 1; index < _tabs.length; index++) {
        final candidate = _tabs[index];
        if (!_isPathAtOrBelow(candidate.path, normalizedPath)) {
          nextActivePath = candidate.path;
          break;
        }
      }
      if (nextActivePath == null) {
        for (var index = activeIndex - 1; index >= 0; index--) {
          final candidate = _tabs[index];
          if (!_isPathAtOrBelow(candidate.path, normalizedPath)) {
            nextActivePath = candidate.path;
            break;
          }
        }
      }
      _tabs[activeIndex].onDeactivate();
    }

    for (final tab in openTabs) {
      tab.onClose();
      tab.dispose();
      unawaited(_tabUpdateSubscriptions.remove(tab.path)?.cancel());
    }
    _tabs.removeWhere(openTabs.contains);

    for (final entry in keptTabs) {
      _keepAliveTabs.remove(entry.key);
      entry.value.onClose();
      entry.value.dispose();
      unawaited(_tabUpdateSubscriptions.remove(entry.key)?.cancel());
    }

    if (activeWasDeleted) {
      _activeTabPath = nextActivePath ?? '';
      activeTab?.onActivate();
    }
    didUpdate();
  }

  void _cancelLoadsAtOrBelow(String path) {
    final matchingPaths = _loadingTabs.keys.where((candidate) => _isPathAtOrBelow(candidate, path)).toList();
    for (final matchingPath in matchingPaths) {
      unawaited(_loadingTabs.remove(matchingPath));
    }
  }

  /// Hook called after one or more tabs have been successfully saved to disk.
  Future<void> didSaveTabs(List<String> paths);

  /// Hook called when the controller state updates (e.g. active tab changes, tab contents are updated, or tabs are saved).
  void didUpdate({bool? isSaving});

  /// Disposes all open and keep-alive tabs, and cleans up any active file subscriptions.
  void disposeAllTabs() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    workspaceController.languageServerClient.setDisplayFileHandler(null);
    unawaited(_workspaceSubscription?.cancel());
    _workspaceSubscription = null;
    for (final subscription in _tabUpdateSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _tabUpdateSubscriptions.clear();
    for (final adapter in adapters) {
      adapter.dispose();
    }
    for (final tab in _tabs) {
      tab.dispose();
    }
    for (final tab in _keepAliveTabs.values) {
      tab.dispose();
    }
    _tabs.clear();
    _keepAliveTabs.clear();
    _loadingTabs.clear();
    _activeTabPath = '';
  }
}

String _normalizeWorkspacePath(String value) {
  final normalized = _workspacePath.normalize(value);
  return normalized == '.' ? '' : normalized;
}

bool _isPathAtOrBelow(String value, String root) {
  final normalizedValue = _normalizeWorkspacePath(value);
  final normalizedRoot = _normalizeWorkspacePath(root);
  return normalizedRoot.isEmpty ||
      normalizedValue == normalizedRoot ||
      _workspacePath.isWithin(normalizedRoot, normalizedValue);
}

String _rebaseWorkspacePath(String value, String oldRoot, String newRoot) {
  final normalizedValue = _normalizeWorkspacePath(value);
  final normalizedOldRoot = _normalizeWorkspacePath(oldRoot);
  final normalizedNewRoot = _normalizeWorkspacePath(newRoot);
  if (normalizedValue == normalizedOldRoot) {
    return normalizedNewRoot;
  }
  return _workspacePath.join(
    normalizedNewRoot,
    _workspacePath.relative(normalizedValue, from: normalizedOldRoot),
  );
}
