// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';
import 'package:web/web.dart' as web;

import '../shared/icons.dart';
import 'components/file_tree_file_item.dart';
import 'components/file_tree_folder_item.dart';
import 'components/file_tree_input_item.dart';
import 'file_tree_models.dart';

/// Renders an interactive tree of workspace files and folders.
final class FileTreeView extends StatefulComponent {
  /// Creates a file tree from the immutable [state] and [actions].
  ///
  /// [confirmDelete] can override the browser confirmation dialog, for
  /// example in tests.
  const FileTreeView({
    required this.state,
    required this.actions,
    this.confirmDelete,
    super.key,
  });

  /// The file-tree state to render.
  final FileTreeState state;

  /// The actions invoked in response to user interaction.
  final FileTreeActions actions;

  /// An optional callback used to confirm destructive operations.
  final bool Function(String message)? confirmDelete;

  @override
  State<FileTreeView> createState() => _FileTreeViewInternalState();
}

final class _FileTreeViewInternalState extends State<FileTreeView> {
  String? _selectedPath;
  String? _creatingInFolder;
  FileTreeEntryKind? _creatingEntry;
  bool _isRootDropTarget = false;
  int _dragEnterCount = 0;

  @override
  void didUpdateComponent(FileTreeView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.state.activeFile != oldComponent.state.activeFile) {
      if (_selectedPath != component.state.activeFile) {
        _selectedPath = null;
      }
    }
  }

  @override
  Component build(BuildContext context) {
    final state = component.state;
    final actions = component.actions;

    return div(classes: 'file-tree', [
      div(classes: 'file-tree-header', [
        const span(classes: 'file-tree-title', [.text('Files')]),
        div(classes: 'file-tree-toolbar', [
          _toolbarButton(
            title: 'New file',
            disabled: state.busy,
            icon: const Icon(
              'note_add',
              size: 16,
              classes: 'file-tree-icon file-icon',
            ),
            onClick: () {
              setState(() {
                _creatingEntry = FileTreeEntryKind.file;
                final path = _selectedPath ?? '';
                _selectedPath = null;
                if (path.isEmpty) {
                  _creatingInFolder = '';
                } else if (state.root.isFolder(path)) {
                  _creatingInFolder = path;
                } else {
                  _creatingInFolder = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
                }
              });
            },
          ),
          _toolbarButton(
            title: 'New folder',
            disabled: state.busy,
            icon: const Icon(
              'create_new_folder',
              size: 16,
              classes: 'file-tree-icon folder-icon',
            ),
            onClick: () {
              setState(() {
                _creatingEntry = FileTreeEntryKind.folder;
                final path = _selectedPath ?? '';
                _selectedPath = null;
                if (path.isEmpty) {
                  _creatingInFolder = '';
                } else if (state.root.isFolder(path)) {
                  _creatingInFolder = path;
                } else {
                  _creatingInFolder = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
                }
              });
            },
          ),
        ]),
      ]),
      if (state.operationError case final error?)
        div(classes: 'file-tree-error', [
          .text(error),
        ]),
      div(
        classes: [
          'file-tree-list',
          if (state.busy) 'busy',
          if (_isRootDropTarget) 'drop-target',
        ].join(' '),
        attributes: {'role': 'tree', 'aria-label': 'Project files'},
        events: {
          'click': (_) {
            setState(() {
              _selectedPath = null;
            });
            actions.clearOperationError();
          },
          'dragover': (event) {
            event.preventDefault();
          },
          'dragenter': (event) {
            event.preventDefault();
            _dragEnterCount++;
            if (!_isRootDropTarget) {
              setState(() {
                _isRootDropTarget = true;
              });
            }
          },
          'dragleave': (event) {
            _dragEnterCount--;
            if (_dragEnterCount <= 0) {
              _dragEnterCount = 0;
              if (_isRootDropTarget) {
                setState(() {
                  _isRootDropTarget = false;
                });
              }
            }
          },
          'drop': (event) {
            event.preventDefault();
            _dragEnterCount = 0;
            setState(() {
              _isRootDropTarget = false;
            });
            final dragEvent = event as web.DragEvent;
            final sourcePath = dragEvent.dataTransfer?.getData('text/plain');
            if (sourcePath != null && sourcePath.isNotEmpty) {
              unawaited(actions.moveEntry(sourcePath, ''));
            }
          },
        },
        [
          if (_creatingEntry != null && _creatingInFolder == '')
            FileTreeInputItem(
              placeholder: _creatingEntry == FileTreeEntryKind.folder ? 'folder' : 'file',
              depth: 0,
              icon: _creatingEntry == FileTreeEntryKind.folder
                  ? const FileIcon(
                      'seti:folder',
                      classes: 'file-tree-icon folder-icon',
                      attributes: {'width': '12', 'height': '12'},
                    )
                  : const FileIcon(
                      'seti:default',
                      classes: 'file-tree-icon file-icon',
                      attributes: {'width': '12', 'height': '12'},
                    ),
              confirmOnBlur: true,
              checkConflict: (name) {
                if (state.root.exists(name)) {
                  return 'A file or folder already exists at "$name".';
                }
                return null;
              },
              onConfirm: (name) async {
                final kind = _creatingEntry!;
                setState(() {
                  _creatingEntry = null;
                  _creatingInFolder = null;
                  _selectedPath = name;
                });
                if (kind == FileTreeEntryKind.folder) {
                  await actions.createFolder('', name);
                } else {
                  await actions.createFile('', name);
                }
              },
              onCancel: () {
                setState(() {
                  _creatingEntry = null;
                  _creatingInFolder = null;
                });
              },
            ),
          ...state.root.children.map((child) {
            if (child is FileTreeFolderNode) {
              return FileTreeFolderItem(
                key: ValueKey('folder-${child.resource.path}'),
                node: child,
                depth: 0,
                state: state,
                actions: actions,
                selectedPath: _selectedPath,
                onSelect: (selectedPath) {
                  setState(() {
                    _selectedPath = selectedPath;
                  });
                },
                creatingInFolder: _creatingInFolder,
                creatingEntry: _creatingEntry,
                onConfirmCreate: (name) async {
                  final parentPath = _creatingInFolder!;
                  final kind = _creatingEntry!;
                  final targetPath = parentPath.isEmpty ? name : '$parentPath/$name';
                  setState(() {
                    _creatingEntry = null;
                    _creatingInFolder = null;
                    _selectedPath = targetPath;
                  });
                  if (kind == FileTreeEntryKind.folder) {
                    await actions.createFolder(parentPath, name);
                  } else {
                    await actions.createFile(parentPath, name);
                  }
                },
                onCancelCreate: () {
                  setState(() {
                    _creatingEntry = null;
                    _creatingInFolder = null;
                  });
                },
                confirmDelete: component.confirmDelete,
              );
            } else {
              return FileTreeFileItem(
                key: ValueKey('file-${child.resource.path}'),
                node: child as FileTreeFileNode,
                depth: 0,
                state: state,
                actions: actions,
                selectedPath: _selectedPath,
                onSelect: (selectedPath) {
                  setState(() {
                    _selectedPath = selectedPath;
                  });
                },
                confirmDelete: component.confirmDelete,
              );
            }
          }),
        ],
      ),
    ]);
  }

  Component _toolbarButton({
    required String title,
    required bool disabled,
    required Component icon,
    required void Function() onClick,
  }) {
    return button(
      classes: 'file-tree-toolbar-button',
      attributes: {
        'title': title,
        'aria-label': title,
        if (disabled) 'disabled': '',
      },
      onClick: disabled ? null : onClick,
      [icon],
    );
  }
}
