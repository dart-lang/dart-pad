// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

/// Narrow editor contract consumed by the file tree.
abstract interface class FileTreeEditorDelegate implements Listenable {
  /// The path of the file displayed in the active editor tab.
  String get activeFile;

  /// The paths of open files with unsaved changes.
  List<String> get dirtyFiles;

  /// Opens the editable text file at [path].
  Future<void> openTextFile(String path);

  /// Persists all unsaved editor tabs.
  Future<void> saveAllTabs();

  /// Displays [message] as a non-fatal editor warning.
  void reportWarning(String message);

  /// Clears user-facing editor errors and warnings.
  void clearMessages();
}
