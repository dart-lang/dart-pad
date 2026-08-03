// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/icons.dart';

/// Standard action buttons (Rename, Delete) displayed on hover for a file tree row.
class FileTreeRowActions extends StatelessComponent {
  const FileTreeRowActions({
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  /// Callback when the rename button is clicked.
  final VoidCallback onRename;

  /// Callback when the delete button is clicked.
  final VoidCallback onDelete;

  @override
  Component build(BuildContext context) {
    return div(classes: 'file-tree-actions', [
      button(
        classes: 'file-tree-action',
        attributes: const {'title': 'Rename', 'aria-label': 'Rename'},
        events: {
          'click': (event) {
            event.stopPropagation();
            onRename();
          },
        },
        [const Icon('edit', size: 12)],
      ),
      button(
        classes: 'file-tree-action delete',
        attributes: const {'title': 'Delete', 'aria-label': 'Delete'},
        events: {
          'click': (event) {
            event.stopPropagation();
            onDelete();
          },
        },
        [const Icon('delete', size: 12)],
      ),
    ]);
  }
}
