// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';

/// Owns the multi-file editor tabs and their workspace lifecycle.
final class TabsViewModel extends ChangeNotifier with TabsController<Component> {
  /// Creates an empty set of tabs backed by [workspaceResourceApi].
  TabsViewModel({
    required WorkspaceResourceApi workspaceResourceApi,
    required List<EditorTabAdapter<Component>> adapters,
  }) {
    init(
      workspaceResourceApi: workspaceResourceApi,
      adapters: adapters,
    );
  }

  bool _isSaving = false;
  String? _errorMessage;
  String? _warningMessage;

  /// Whether a save operation is in progress.
  bool get isSaving => _isSaving;

  /// The latest user-facing editor error, or `null` if there is none.
  String? get errorMessage => _errorMessage;

  /// The latest user-facing editor warning, or `null` if there is none.
  String? get warningMessage => _warningMessage;

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
    notifyListeners();
  }

  @override
  Future<void> saveAllTabs() async {
    try {
      await super.saveAllTabs();
    } catch (_) {
      _reportError('Could not save all files.');
      rethrow;
    }
  }

  /// Opens the text file at [path] and reports failures to the user.
  Future<void> openTextFile(String path) async {
    try {
      await openFile(path);
      clearMessages();
    } catch (_) {
      _reportError('Could not open $path.');
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

  /// Publishes [message] as the current user-facing warning.
  void reportWarning(String message) {
    _warningMessage = message;
    notifyListeners();
  }

  /// Clears the current user-facing error and warning messages.
  void clearMessages() {
    if (_errorMessage == null && _warningMessage == null) {
      return;
    }
    _errorMessage = null;
    _warningMessage = null;
    notifyListeners();
  }

  void _reportError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeAllTabs();
    super.dispose();
  }
}
