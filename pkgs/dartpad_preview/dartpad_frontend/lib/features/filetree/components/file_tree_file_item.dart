// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';
import 'package:web/web.dart' as web;

import '../../shared/icons.dart';
import '../file_tree_models.dart';
import 'file_tree_input_item.dart';

/// A stateful item representing a file node.
class FileTreeFileItem extends StatefulComponent {
  const FileTreeFileItem({
    required this.node,
    required this.depth,
    required this.state,
    required this.actions,
    required this.selectedPath,
    required this.onSelect,
    this.confirmDelete,
    super.key,
  });

  final FileTreeFileNode node;
  final int depth;
  final FileTreeState state;
  final FileTreeActions actions;
  final String? selectedPath;
  final void Function(String path) onSelect;
  final bool Function(String message)? confirmDelete;

  @override
  State<FileTreeFileItem> createState() => _FileTreeFileItemState();
}

class _FileTreeFileItemState extends State<FileTreeFileItem> {
  bool _isRenaming = false;
  bool _isDragging = false;

  @override
  Component build(BuildContext context) {
    final path = component.node.resource.path;
    final protected = component.state.protectedEntries.contains(path);
    final openable = component.node.openable;
    final selected = component.selectedPath == path;
    final active = component.selectedPath == null && component.state.activeFile == path;
    final dim = component.node.isIgnored;

    if (_isRenaming) {
      return FileTreeInputItem(
        initialValue: component.node.resource.shortName,
        depth: component.depth,
        icon: _fileIcon(component.node.resource.shortName),
        checkConflict: (newName) {
          final parentPath = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
          final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
          if (newPath != path && component.state.root.exists(newPath)) {
            return 'A file or folder already exists at "$newPath".';
          }
          return null;
        },
        onConfirm: (newName) async {
          setState(() {
            _isRenaming = false;
          });
          final parentPath = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
          final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
          await component.actions.renameFile(path, newName);
          component.onSelect(newPath);
        },
        onCancel: () {
          setState(() {
            _isRenaming = false;
          });
        },
      );
    }

    return div(
      classes: [
        'file-tree-item file',
        if (active) 'active',
        if (selected) 'selected',
        if (dim) 'dim',
        if (!openable) 'binary',
        if (_isDragging) 'dragging',
      ].join(' '),
      styles: Styles(raw: {'--tree-depth': '${component.depth}'}),
      attributes: {
        'title': openable ? path : '$path — binary preview is not available',
        'tabindex': '0',
        'role': 'treeitem',
        'aria-disabled': openable ? 'false' : 'true',
        'draggable': protected || component.state.busy ? 'false' : 'true',
      },
      events: {
        'click': (event) {
          event.stopPropagation();
          component.actions.clearOperationError();
          component.onSelect(path);
          if (openable) {
            unawaited(Future<void>.sync(() => component.actions.openFile(path)));
          }
        },
        'keydown': (event) {
          final keyboardEvent = event as web.KeyboardEvent;
          if (openable && (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ')) {
            component.onSelect(path);
            unawaited(Future<void>.sync(() => component.actions.openFile(path)));
          }
        },
        'dragstart': (event) {
          if (protected || component.state.busy) {
            event.preventDefault();
            return;
          }
          final dragEvent = event as web.DragEvent;
          dragEvent.dataTransfer?.setData('text/plain', path);
          dragEvent.dataTransfer?.effectAllowed = 'move';
          setState(() {
            _isDragging = true;
          });
        },
        'dragend': (_) => setState(() {
          _isDragging = false;
        }),
      },
      [
        const span(classes: 'file-tree-disclosure spacer', []),
        _fileIcon(component.node.resource.shortName),
        span(classes: 'file-tree-name', [.text(component.node.resource.shortName)]),
        if (!protected)
          _rowActions(
            onRename: () {
              component.onSelect(path);
              setState(() {
                _isRenaming = true;
              });
            },
            onDelete: () => _confirmDeleteFile(path),
          ),
      ],
    );
  }

  Component _rowActions({
    required void Function() onRename,
    required void Function() onDelete,
  }) {
    return div(classes: 'file-tree-actions', [
      button(
        classes: 'file-tree-action',
        attributes: {'title': 'Rename', 'aria-label': 'Rename'},
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
        attributes: {'title': 'Delete', 'aria-label': 'Delete'},
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

  Component _fileIcon(String fileName) {
    final lowerName = fileName.toLowerCase();
    final colorClass = switch (lowerName) {
      final path when path.endsWith('.dart') => 'file-icon-dart',
      final path when path.endsWith('.yaml') || path.endsWith('.yml') => 'file-icon-yaml',
      _ => 'file-icon',
    };
    return FileIcon.forFile(
      fileName,
      classes: 'file-tree-icon $colorClass',
      attributes: const {'aria-hidden': 'true', 'width': '12', 'height': '12'},
    );
  }

  void _confirmDeleteFile(String path) {
    final dirty = component.state.dirtyEntries.contains(path);
    final message = dirty
        ? 'Delete "$path"? Its unsaved editor changes will be lost.'
        : 'Delete "$path"? This cannot be undone.';
    final confirmed = component.confirmDelete?.call(message) ?? web.window.confirm(message);
    if (confirmed) {
      unawaited(component.actions.deleteFile(path));
    }
  }
}
