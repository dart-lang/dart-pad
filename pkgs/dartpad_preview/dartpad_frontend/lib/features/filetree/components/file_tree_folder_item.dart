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
import 'file_tree_file_item.dart';
import 'file_tree_input_item.dart';

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
    super.key,
  });

  final FileTreeFolderNode node;
  final int depth;
  final FileTreeState state;
  final FileTreeActions actions;
  final String? selectedPath;
  final void Function(String path) onSelect;
  final String? creatingInFolder;
  final FileTreeEntryKind? creatingEntry;
  final void Function(String name) onConfirmCreate;
  final void Function() onCancelCreate;
  final bool Function(String message)? confirmDelete;

  @override
  State<FileTreeFolderItem> createState() => _FileTreeFolderItemState();
}

class _FileTreeFolderItemState extends State<FileTreeFolderItem> {
  final _folderKey = GlobalNodeKey<web.HTMLElement>();
  bool _isCollapsed = false;
  bool _isRenaming = false;
  bool _isDragging = false;
  bool _isDropTarget = false;
  int _dragEnterCount = 0;

  @override
  void initState() {
    super.initState();
    _isCollapsed = component.node.isIgnored;
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

    final folderRow = div(
      classes: [
        'file-tree-item folder',
        if (selected) 'selected',
        if (dim) 'dim',
        if (_isDragging) 'dragging',
      ].join(' '),
      attributes: {
        'title': path,
        'tabindex': '0',
        'role': 'treeitem',
        'aria-expanded': _isCollapsed ? 'false' : 'true',
        'draggable': protected || component.state.busy ? 'false' : 'true',
      },
      events: {
        'click': (event) {
          event.stopPropagation();
          component.onSelect(path);
        },
        'dblclick': (event) {
          event.stopPropagation();
          component.onSelect(path);
          _toggleCollapsed();
        },
        'keydown': (event) {
          final keyboardEvent = event as web.KeyboardEvent;
          if (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ') {
            setState(() {
              _isCollapsed = !_isCollapsed;
            });
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
        button(
          classes: 'file-tree-disclosure',
          attributes: {
            'title': _isCollapsed ? 'Expand' : 'Collapse',
            'aria-label': _isCollapsed ? 'Expand $path' : 'Collapse $path',
          },
          events: {
            'click': (event) {
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
          _rowActions(
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

    return div(
      key: _folderKey,
      classes: [
        'file-tree-folder',
        if (_isDropTarget) 'drop-target',
      ].join(' '),
      styles: Styles(raw: {'--tree-depth': '${component.depth}'}),
      events: {
        'dragover': (event) {
          if (component.state.busy) {
            return;
          }
          event
            ..stopPropagation()
            ..preventDefault();
        },
        'dragenter': (event) {
          if (component.state.busy) {
            return;
          }
          event
            ..stopPropagation()
            ..preventDefault();
          _dragEnterCount++;
          if (!_isDropTarget) {
            setState(() {
              _isDropTarget = true;
            });
          }
        },
        'dragleave': (event) {
          event.stopPropagation();
          _dragEnterCount--;
          if (_dragEnterCount <= 0) {
            _dragEnterCount = 0;
            if (_isDropTarget) {
              setState(() {
                _isDropTarget = false;
              });
            }
          }
        },
        'drop': (event) {
          event
            ..stopPropagation()
            ..preventDefault();
          _dragEnterCount = 0;
          setState(() {
            _isDropTarget = false;
          });
          final dragEvent = event as web.DragEvent;
          final sourcePath = dragEvent.dataTransfer?.getData('text/plain');
          if (sourcePath != null && sourcePath != path) {
            unawaited(component.actions.moveEntry(sourcePath, path));
          }
        },
      },
      [
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
