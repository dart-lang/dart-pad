import 'dart:async';
import 'package:path/path.dart' as p;

import 'tabs_controller.dart';

/// Represents a tab in the editor workspace associated with a specific file path.
///
/// Implementations of [EditorTab] specify how to build the tab's UI (via [build])
/// and handle lifecycle events.
abstract class EditorTab<T> {
  EditorTab(this.path);

  /// The file path associated with this tab.
  String path;

  /// The display name of the tab, derived from the file path.
  String get name => p.posix.basename(path);

  /// Whether this tab should be kept in memory when closed.
  bool get keepAlive => false;

  /// Called when the tab becomes active or focused in the workspace.
  void onActivate() {}

  /// Called when the tab loses active focus in the workspace.
  void onDeactivate() {}

  /// Called when the tab is closed by the user.
  void onClose() {}

  /// Called when the tab is permanently deleted or discarded.
  void dispose() {}

  /// Renames the file path associated with this tab in-place.
  void rename(String newPath) {
    path = newPath;
  }

  /// A stream that emits when the tab state is updated.
  Stream<void> get onUpdate => const Stream.empty();

  /// Whether this tab has unsaved changes.
  bool get hasUnsavedChanges => false;

  /// Saves the content of this tab.
  Future<void> save() => Future.value();

  /// Discards unsaved changes in this tab.
  void discardUnsavedChanges() {}

  /// Builds the ui representation of the tab.
  T build();
}

/// An adapter responsible for registering tab creation logic and managing
/// the lifecycle of the tabs within a [TabsController].
abstract class EditorTabAdapter<T> {
  const EditorTabAdapter();

  /// Registers this adapter with the given [tabs] controller.
  void register(TabsController<T> tabs) {}

  /// Disposes of any resources held by this adapter.
  void dispose() {}

  /// Creates a new [EditorTab] for the given [path], or returns `null`
  /// if this adapter does not handle the given path.
  Future<EditorTab<T>?> createTab(String path);
}
