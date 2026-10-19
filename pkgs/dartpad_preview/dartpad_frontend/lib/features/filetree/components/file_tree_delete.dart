// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:web/web.dart' as web;

import '../../shared/components/context_menu.dart';
import '../../shared/components/shortcut_definitions.dart';

/// Whether [event] is the platform delete shortcut
bool isDeleteShortcut(web.KeyboardEvent event) {
  return isMac ? event.key == 'Backspace' && event.metaKey : event.key == 'Delete';
}

/// Confirms [message], then calls [delete] with [path] if confirmed.
void confirmDeleteFileTreeRow({
  required String path,
  required String message,
  required Future<void> Function(String path) delete,
  bool Function(String message)? confirmDelete,
}) {
  final confirmed = confirmDelete?.call(message) ?? web.window.confirm(message);
  if (confirmed) {
    unawaited(delete(path));
  }
}

/// The context menu item that triggers a delete, with the platform shortcut hint.
ContextMenuItem deleteEntryMenuItem({required void Function() onPressed}) {
  return ContextMenuItem(
    label: 'Delete',
    destructive: true,
    shortcut: ShortcutDefinition.deleteFile.resolvedDisplayKey,
    onPressed: onPressed,
  );
}
