import 'dart:async';

import '../lsp/language_server_client.dart';
import '../workspace/workspace_controller.dart';
import '../workspace/workspace_watcher.dart';
import 'editor_tab.dart';

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

  final List<EditorTab<T>> _tabs = [];
  final Map<String, EditorTab<T>> _keepAliveTabs = {};
  final Map<String, Future<EditorTab<T>>> _loadingTabs = {};
  final Map<String, StreamSubscription<void>> _tabUpdateSubscriptions = {};
  String _activeTabPath = '';
  StreamSubscription<WorkspaceChangeEvent>? _workspaceSubscription;

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
  bool get hasUnsavedChanges => _tabs.any((t) => t.hasUnsavedChanges);

  /// Returns the paths of all files that currently have unsaved changes.
  List<String> get dirtyFiles => [
    for (final t in _tabs)
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

    Future<EditorTab<T>>? tabFuture = _loadingTabs[fileName];
    if (tabFuture == null) {
      tabFuture = _createTab(fileName);
      _loadingTabs[fileName] = tabFuture;
    }

    try {
      final tab = await tabFuture;

      // Check if it got cancelled or deleted while loading
      if (!_loadingTabs.containsKey(fileName)) {
        tab.dispose();
        return;
      }

      if (!_tabs.any((t) => t.path == fileName)) {
        _tabs.add(tab);
      }
      _setActivePath(fileName);
    } catch (e) {
      // Handle error
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
    for (final tab in openTabs) {
      if (tab.hasUnsavedChanges) {
        savedFiles.add(tab.path);
      }
    }
    if (savedFiles.isEmpty) {
      return;
    }

    didUpdate(isSaving: true);
    try {
      for (final tab in openTabs) {
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
    for (final tab in _tabs) {
      if (tab.hasUnsavedChanges) {
        tab.discardUnsavedChanges();
      }
    }
    didUpdate();
  }

  Future<void> _handleDisplayFile(String uri) async {
    final folderPath = workspaceController.workspace.workspaceFolder.path;
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
    unawaited(_loadingTabs.remove(oldPath));

    final tabIndex = _tabs.indexWhere((t) => t.path == oldPath);
    if (tabIndex != -1) {
      final tab = _tabs[tabIndex];
      tab.rename(newPath);
      if (_activeTabPath == oldPath) {
        _activeTabPath = newPath;
      }
      didUpdate();
      return;
    }

    final keptTab = _keepAliveTabs.remove(oldPath);
    if (keptTab != null) {
      keptTab.rename(newPath);
      _keepAliveTabs[newPath] = keptTab;
    }
  }

  void _handleDeletedFile(String path) {
    unawaited(_loadingTabs.remove(path));

    final tabIndex = _tabs.indexWhere((t) => t.path == path);
    if (tabIndex != -1) {
      final tab = _tabs[tabIndex];
      final wasActive = path == _activeTabPath;
      String? nextFile;
      if (wasActive && _tabs.length > 1) {
        nextFile = _tabs[tabIndex + 1 < _tabs.length ? tabIndex + 1 : tabIndex - 1].path;
      }

      if (wasActive) {
        tab.onDeactivate();
      }
      tab.onClose();
      tab.dispose();

      _tabs.removeAt(tabIndex);
      if (wasActive) {
        _setActivePath(nextFile ?? '');
      } else {
        didUpdate();
      }
      return;
    }

    final keptTab = _keepAliveTabs.remove(path);
    if (keptTab != null) {
      keptTab.onClose();
      keptTab.dispose();
    }
  }

  /// Hook called after one or more tabs have been successfully saved to disk.
  Future<void> didSaveTabs(List<String> paths);

  /// Hook called when the controller state updates (e.g. active tab changes, tab contents are updated, or tabs are saved).
  void didUpdate({bool? isSaving});

  /// Disposes all open and keep-alive tabs, and cleans up any active file subscriptions.
  void disposeAllTabs() {
    _workspaceSubscription?.cancel();
    for (final adapter in adapters) {
      adapter.dispose();
    }
    for (final tab in _tabs) {
      tab.dispose();
    }
    for (final tab in _keepAliveTabs.values) {
      tab.dispose();
    }
  }
}
