// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import '../editor/view_models/tabs_view_model.dart';
import '../shared/editable_text_file.dart';
import 'file_tree_editor_delegate.dart';

/// Adapts editor tabs to the narrow contract required by the file tree.
final class FileTreeTabsAdapter implements FileTreeEditorDelegate {
  /// Creates an adapter backed by [tabs].
  FileTreeTabsAdapter(this.tabs);

  /// The editor tab model adapted by this instance.
  final TabsViewModel tabs;

  @override
  String get activeFile => tabs.activeFile;

  @override
  List<String> get dirtyFiles => tabs.dirtyFiles;

  @override
  void addListener(VoidCallback listener) => tabs.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => tabs.removeListener(listener);

  @override
  void clearMessages() => tabs.clearMessages();

  @override
  Future<void> openTextFile(String path) {
    if (!isEditableTextFile(path)) {
      tabs.reportWarning('Binary preview is not available for $path.');
      return Future.value();
    }
    return tabs.openTextFile(path);
  }

  @override
  void reportWarning(String message) => tabs.reportWarning(message);

  @override
  Future<void> saveAllTabs() => tabs.saveAllTabs();
}
