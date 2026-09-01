// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';
import 'package:web/web.dart' as web;

import '../../shared/components/context_menu.dart';
import '../file_tree_models.dart';
import 'file_tree_input_item.dart';
import 'file_tree_row.dart';

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
    this.contextMenu,
    super.key,
  });

  /// The file node that this item represents.
  final FileTreeFileNode node;

  /// The depth of this item in the file tree, used to determine indentation.
  final int depth;

  /// The current state of the file tree.
  final FileTreeState state;

  /// The actions available for file tree manipulation.
  final FileTreeActions actions;

  /// The path of the currently selected node, if any.
  final String? selectedPath;

  /// Callback when this file item is selected.
  final void Function(String path) onSelect;

  /// Optional callback to confirm deletion of this file.
  final bool Function(String message)? confirmDelete;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  @override
  State<FileTreeFileItem> createState() => _FileTreeFileItemState();
}

class _FileTreeFileItemState extends State<FileTreeFileItem> {
  final _rowKey = GlobalNodeKey<web.HTMLElement>();
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    final path = component.node.resource.path;
    final active = component.selectedPath == null && component.state.activeFile == path;
    if (active) {
      _scrollIntoView();
    }
  }

  @override
  void didUpdateComponent(FileTreeFileItem oldComponent) {
    super.didUpdateComponent(oldComponent);
    final path = component.node.resource.path;
    final active = component.selectedPath == null && component.state.activeFile == path;
    final oldActive = oldComponent.selectedPath == null && oldComponent.state.activeFile == path;
    if (active && !oldActive) {
      _scrollIntoView();
    }
  }

  void _scrollIntoView() {
    unawaited(
      Future<void>.delayed(Duration.zero, () {
        final node = _rowKey.currentNode;
        final root = node?.closest('.file-tree-list');
        if (node != null) {
          node.scrollIntoView(
            web.ScrollIntoViewOptions(
              behavior: 'instant',
              block: 'start',
            ),
          );
          if (root != null) {
            // Scroll up to account for sticky parent folder items.
            root.scrollBy(
              web.ScrollToOptions(
                top: -25 * component.depth,
                behavior: 'instant',
              ),
            );
          }
        }
      }),
    );
  }

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
        checkConflict: (newName) => component.state.checkFileTreeConflict(currentPath: path, newName: newName),
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

    return FileTreeRow(
      key: _rowKey,
      depth: component.depth,
      classes: [
        'file-tree-item file',
        if (active) 'active',
        if (selected) 'selected',
        if (dim) 'dim',
        if (!openable) 'binary',
      ].join(' '),
      path: path,
      isDraggable: !protected && !component.state.busy,
      attributes: {
        'title': openable ? path : '$path — binary preview is not available',
        'tabindex': '0',
        'role': 'treeitem',
        'aria-disabled': openable ? 'false' : 'true',
      },
      events: {
        'click': (web.Event event) {
          event.stopPropagation();
          component.actions.clearOperationError();
          component.onSelect(path);
          if (openable) {
            unawaited(Future<void>.sync(() => component.actions.openFile(path)));
          }
        },
        'keydown': (web.Event event) {
          final keyboardEvent = event as web.KeyboardEvent;
          if (openable && (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ')) {
            component.onSelect(path);
            unawaited(Future<void>.sync(() => component.actions.openFile(path)));
          }
        },
        'contextmenu': (web.Event event) => _handleContextMenu(
          event,
          path,
          openable: openable,
          protected: protected,
        ),
      },
      children: [
        const span(classes: 'file-tree-disclosure spacer', []),
        _fileIcon(component.node.resource.shortName),
        span(classes: 'file-tree-name', [.text(component.node.resource.shortName)]),
      ],
    );
  }

  void _handleContextMenu(
    web.Event event,
    String path, {
    required bool openable,
    required bool protected,
  }) {
    final menu = component.contextMenu;
    if (menu == null) {
      return;
    }
    final mouseEvent = event as web.MouseEvent;
    event.preventDefault();
    event.stopPropagation();
    component.actions.clearOperationError();
    component.onSelect(path);
    menu.show(
      mouseEvent.clientX.toDouble(),
      mouseEvent.clientY.toDouble(),
      _buildContextMenuItems(path, openable: openable, protected: protected),
    );
  }

  List<ContextMenuEntry> _buildContextMenuItems(
    String path, {
    required bool openable,
    required bool protected,
  }) {
    return [
      if (openable)
        ContextMenuItem(
          label: 'Open',
          onPressed: () {
            unawaited(Future<void>.sync(() => component.actions.openFile(path)));
          },
        ),
      if (!protected) ...[
        ContextMenuItem(
          label: 'Rename',
          onPressed: () {
            setState(() {
              _isRenaming = true;
            });
          },
        ),
        ContextMenuItem(
          label: 'Delete',
          destructive: true,
          onPressed: () => _confirmDeleteFile(path),
        ),
        const ContextMenuDivider(),
      ],
      ContextMenuItem(
        label: 'Copy path',
        onPressed: () {
          unawaited(web.window.navigator.clipboard.writeText(path).toDart.catchError((Object? _) => null));
        },
      ),
    ];
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
