// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';
import '../codemirror/code_mirror_tab.dart';

/// Owns the multi-file editor tabs and their workspace lifecycle.
final class TabsViewModel extends ChangeNotifier with TabsController<Component> {
  /// Creates an empty set of tabs backed by [workspaceResourceApi].
  TabsViewModel({
    required this.events,
    required WorkspaceResourceApi workspaceResourceApi,
    required List<EditorTabAdapter<Component>> adapters,
  }) {
    init(
      workspaceResourceApi: workspaceResourceApi,
      adapters: adapters,
    );
  }

  /// The event bus used for save and error messages.
  final AppEventBus events;

  bool _isSaving = false;
  String? _errorMessage;

  /// Whether a save operation is in progress.
  bool get isSaving => _isSaving;

  /// The latest user-facing editor error, or `null` if there is none.
  String? get errorMessage => _errorMessage;

  @override
  void didUpdate({bool? isSaving}) {
    if (isSaving != null) {
      _isSaving = isSaving;
    }
    notifyListeners();
  }

  @override
  Future<void> didSaveTabs(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    _errorMessage = null;
    events.dispatch(LogEvent('Saved ${paths.join(', ')}.'));
    notifyListeners();
  }

  @override
  Future<void> saveAllTabs() async {
    try {
      await super.saveAllTabs();
    } catch (error, stackTrace) {
      _reportError('Could not save all files.', error, stackTrace);
      rethrow;
    }
  }

  /// Requests fresh semantic highlighting for the visible editor.
  void refreshSemanticHighlighting() {
    final tab = activeTab;
    if (tab is CodeMirrorTab && tab.container.isConnected) {
      tab.editor.triggerLspRefresh();
    }
  }

  /// Closes [path], requiring explicit permission before discarding changes.
  bool closeFile(String path, {bool discardChanges = false}) {
    final tab = getTab(path);
    if (tab == null) {
      return false;
    }
    if (tab.hasUnsavedChanges) {
      if (!discardChanges) {
        return false;
      }
      tab.discardUnsavedChanges();
    }
    closeTab(path);
    return true;
  }

  void _reportError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _errorMessage = message;
    events.dispatch(
      LogEvent(
        message,
        level: Level.SEVERE,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    disposeAllTabs();
    super.dispose();
  }
}
