// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';
import 'package:web/web.dart' as web;

import '../../shared/icons.dart';
import '../file_tree_models.dart';
import 'file_tree_file_item.dart';
import 'file_tree_input_item.dart';
import 'file_tree_row.dart';
import 'file_tree_row_actions.dart';

/// A stateful item representing a folder node.
class FileTreeFolderItem extends StatefulComponent {
  const FileTreeFolderItem({
    required this.node,
    required this.depth,
    required this.state,
    required this.actions,
    required this.selectedPath,
    required this.onSelect,
    this.creatingInFolder,
    this.creatingEntry,
    required this.onConfirmCreate,
    required this.onCancelCreate,
    this.confirmDelete,
    this.collapseAllCount = 0,
    super.key,
  });

  /// The folder node that this item represents.
  final FileTreeFolderNode node;

  /// The depth of this item in the file tree, used to determine indentation.
  final int depth;

  /// The current state of the file tree.
  final FileTreeState state;

  /// The actions available for file tree manipulation.
  final FileTreeActions actions;

  /// The path of the currently selected node, if any.
  final String? selectedPath;

  /// Callback when this folder item is selected.
  final void Function(String path) onSelect;

  /// The path of the folder in which a new entry is being created, if any.
  final String? creatingInFolder;

  /// The kind of entry (file or folder) being created, if any.
  final FileTreeEntryKind? creatingEntry;

  /// Callback when creation of a new entry is confirmed with a name.
  final void Function(String name) onConfirmCreate;

  /// Callback when creation of a new entry is cancelled.
  final void Function() onCancelCreate;

  /// Optional callback to confirm deletion of this folder and its contents.
  final bool Function(String message)? confirmDelete;

  /// Trigger generation counter to collapse all folders recursively.
  final int collapseAllCount;

  @override
  State<FileTreeFolderItem> createState() => _FileTreeFolderItemState();
}

class _FileTreeFolderItemState extends State<FileTreeFolderItem> {
  final _folderKey = GlobalNodeKey<web.HTMLElement>();
  bool _isCollapsed = false;
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    final expectedLibPath = workspaceContext.join(component.state.focusedPath, 'lib');
    final activeFile = component.state.activeFile;
    final folderPath = component.node.resource.path;
    final isActiveParent =
        folderPath.isNotEmpty && workspaceContext.isWithinFolder(activeFile, folderPath) && activeFile != folderPath;

    if (folderPath == expectedLibPath || isActiveParent) {
      _isCollapsed = false;
    } else {
      _isCollapsed = true;
    }
  }

  void _toggleCollapsed() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    if (_isCollapsed) {
      _scrollTopIntoView();
    }
  }

  @override
  void didUpdateComponent(FileTreeFolderItem oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.creatingEntry != null && component.creatingInFolder == component.node.resource.path) {
      _isCollapsed = false;
      _scrollTopIntoView();
    }
    if (component.collapseAllCount != oldComponent.collapseAllCount) {
      _isCollapsed = true;
    }

    final activeFile = component.state.activeFile;
    final folderPath = component.node.resource.path;
    final isActiveParent =
        folderPath.isNotEmpty && workspaceContext.isWithinFolder(activeFile, folderPath) && activeFile != folderPath;

    if (isActiveParent && activeFile != oldComponent.state.activeFile) {
      _isCollapsed = false;
    }
  }

  void _scrollTopIntoView() {
    unawaited(
      Future<void>.delayed(Duration.zero, () {
        final node = _folderKey.currentNode;
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
    final selected = component.selectedPath == path;

    if (_isRenaming) {
      return FileTreeInputItem(
        initialValue: component.node.resource.shortName,
        depth: component.depth,
        icon: const FileIcon(
          'seti:folder',
          classes: 'file-tree-icon folder-icon',
          attributes: {'aria-hidden': 'true', 'width': '12', 'height': '12'},
        ),
        checkConflict: (newName) => component.state.checkFileTreeConflict(currentPath: path, newName: newName),
        onConfirm: (newName) async {
          setState(() {
            _isRenaming = false;
          });
          final parentPath = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
          final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
          await component.actions.renameFolder(path, newName);
          component.onSelect(newPath);
        },
        onCancel: () {
          setState(() {
            _isRenaming = false;
          });
        },
      );
    }

    final dim = component.node.isIgnored;

    final folderRow = FileTreeRow(
      depth: component.depth,
      classes: [
        'file-tree-item folder',
        if (selected) 'selected',
        if (dim) 'dim',
      ].join(' '),
      path: path,
      isDraggable: !protected && !component.state.busy,
      attributes: {
        'title': path,
        'tabindex': '0',
        'role': 'treeitem',
        'aria-expanded': _isCollapsed ? 'false' : 'true',
      },
      events: {
        'click': (web.Event event) {
          event.stopPropagation();
          component.onSelect(path);
        },
        'dblclick': (web.Event event) {
          event.stopPropagation();
          component.onSelect(path);
          _toggleCollapsed();
        },
        'keydown': (web.Event event) {
          final keyboardEvent = event as web.KeyboardEvent;
          if (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ') {
            setState(() {
              _isCollapsed = !_isCollapsed;
            });
          }
        },
      },
      children: [
        button(
          classes: 'file-tree-disclosure',
          attributes: {
            'title': _isCollapsed ? 'Expand' : 'Collapse',
            'aria-label': _isCollapsed ? 'Expand $path' : 'Collapse $path',
          },
          events: {
            'click': (web.Event event) {
              event.stopPropagation();
              _toggleCollapsed();
            },
          },
          [
            if (component.node.children.isNotEmpty) Icon(_isCollapsed ? 'chevron_right' : 'expand_more', size: 16),
          ],
        ),
        const FileIcon(
          'seti:folder',
          classes: 'file-tree-icon folder-icon',
          attributes: {'aria-hidden': 'true', 'width': '12', 'height': '12'},
        ),
        span(classes: 'file-tree-name', [.text(component.node.resource.shortName)]),
        if (!protected)
          FileTreeRowActions(
            onRename: () {
              component.onSelect(path);
              setState(() {
                _isRenaming = true;
              });
            },
            onDelete: () => _confirmDeleteFolder(path),
          ),
      ],
    );

    return FileTreeRow(
      key: _folderKey,
      depth: component.depth,
      classes: 'file-tree-folder',
      path: path,
      onDrop: component.state.busy
          ? null
          : (sourcePath) {
              if (sourcePath != path) {
                unawaited(component.actions.moveEntry(sourcePath, path));
              }
            },
      children: [
        folderRow,
        if (!_isCollapsed)
          div(classes: 'file-tree-folder-children', [
            if (component.creatingEntry == FileTreeEntryKind.folder && component.creatingInFolder == path)
              FileTreeInputItem(
                depth: component.depth + 1,
                icon: const FileIcon(
                  'seti:folder',
                  classes: 'file-tree-icon folder-icon',
                  attributes: {'aria-hidden': 'true', 'width': '12', 'height': '12'},
                ),
                confirmOnBlur: true,
                checkConflict: (name) {
                  final targetPath = path.isEmpty ? name : '$path/$name';
                  if (component.state.root.exists(targetPath)) {
                    return 'A file or folder already exists at "$targetPath".';
                  }
                  return null;
                },
                onConfirm: component.onConfirmCreate,
                onCancel: component.onCancelCreate,
              ),
            ...component.node.children.whereType<FileTreeFolderNode>().map((child) {
              return FileTreeFolderItem(
                key: ValueKey('folder-${child.resource.path}'),
                node: child,
                depth: component.depth + 1,
                state: component.state,
                actions: component.actions,
                selectedPath: component.selectedPath,
                onSelect: component.onSelect,
                creatingInFolder: component.creatingInFolder,
                creatingEntry: component.creatingEntry,
                onConfirmCreate: component.onConfirmCreate,
                onCancelCreate: component.onCancelCreate,
                confirmDelete: component.confirmDelete,
                collapseAllCount: component.collapseAllCount,
              );
            }),
            if (component.creatingEntry == FileTreeEntryKind.file && component.creatingInFolder == path)
              FileTreeInputItem(
                depth: component.depth + 1,
                icon: const FileIcon(
                  'seti:default',
                  classes: 'file-tree-icon file-icon',
                  attributes: {'aria-hidden': 'true', 'width': '12', 'height': '12'},
                ),
                confirmOnBlur: true,
                checkConflict: (name) {
                  final targetPath = path.isEmpty ? name : '$path/$name';
                  if (component.state.root.exists(targetPath)) {
                    return 'A file or folder already exists at "$targetPath".';
                  }
                  return null;
                },
                onConfirm: component.onConfirmCreate,
                onCancel: component.onCancelCreate,
              ),
            ...component.node.children.whereType<FileTreeFileNode>().map((child) {
              return FileTreeFileItem(
                key: ValueKey('file-${child.resource.path}'),
                node: child,
                depth: component.depth + 1,
                state: component.state,
                actions: component.actions,
                selectedPath: component.selectedPath,
                onSelect: component.onSelect,
                confirmDelete: component.confirmDelete,
              );
            }),
          ]),
      ],
    );
  }

  void _confirmDeleteFolder(String path) {
    final dirty = component.state.dirtyEntries.contains(path);
    final message = dirty
        ? 'Delete "$path" and all of its contents? Unsaved editor changes inside it will be lost.'
        : 'Delete "$path" and all of its contents? This cannot be undone.';
    final confirmed = component.confirmDelete?.call(message) ?? web.window.confirm(message);
    if (confirmed) {
      unawaited(component.actions.deleteFolder(path));
    }
  }
}
