// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';
import 'package:web/web.dart' as web;

import '../shared/icons.dart';
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
  State<FileTreeView> createState() => _FileTreeViewState();
}

final class _FileTreeViewState extends State<FileTreeView> {
  static const String _newEntryInputSelector = '[data-role="new-tree-entry-input"]';

  String? _scheduledFocusKey;

  @override
  Component build(BuildContext context) {
    final state = component.state;
    final actions = component.actions;
    _scheduleCreateInputFocus(state);

    return div(classes: 'file-tree', [
      div(classes: 'file-tree-header', [
        const span(classes: 'file-tree-title', [.text('Files')]),
        div(classes: 'file-tree-toolbar', [
          _toolbarButton(
            title: 'New file',
            disabled: state.busy,
            icon: const FileIcon(
              'seti:default',
              classes: 'file-tree-icon file-icon',
            ),
            onClick: actions.startAddingFile,
          ),
          _toolbarButton(
            title: 'New folder',
            disabled: state.busy,
            icon: const FileIcon(
              'seti:folder',
              classes: 'file-tree-icon folder-icon',
            ),
            onClick: actions.startAddingFolder,
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
          if (state.dropTargetFolder == '') 'drop-target',
          if (state.busy) 'busy',
        ].join(' '),
        attributes: {'role': 'tree', 'aria-label': 'Project files'},
        events: {
          'click': (_) => actions.clearFolderSelection(),
          'dragover': (event) {
            event.preventDefault();
            actions.markDropTarget('');
          },
          'dragleave': (_) => actions.clearDropTarget(''),
          'drop': (event) {
            event.preventDefault();
            unawaited(actions.dropIntoFolder(''));
          },
        },
        [
          if (state.creatingEntry != null && state.createTargetFolder.isEmpty) _buildCreateInput(state, actions, 0),
          ..._buildChildren(state.root, state, actions, 0),
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

  List<Component> _buildChildren(
    FileTreeFolderNode folder,
    FileTreeState state,
    FileTreeActions actions,
    int depth,
  ) {
    final result = <Component>[];
    for (final child in folder.children) {
      switch (child) {
        case FileTreeFolderNode():
          result.add(_buildFolder(child, state, actions, depth));
          if (!state.collapsedFolders.contains(child.resource.path)) {
            if (state.creatingEntry != null && state.createTargetFolder == child.resource.path) {
              result.add(_buildCreateInput(state, actions, depth + 1));
            }
            result.addAll(_buildChildren(child, state, actions, depth + 1));
          }
        case FileTreeFileNode():
          result.add(_buildFile(child, state, actions, depth));
      }
    }
    return result;
  }

  Component _buildFolder(
    FileTreeFolderNode node,
    FileTreeState state,
    FileTreeActions actions,
    int depth,
  ) {
    final path = node.resource.path;
    final collapsed = state.collapsedFolders.contains(path);
    final selected = state.selectedFolder == path;
    final protected = state.protectedEntries.contains(path);
    final renaming = state.renamingFolder == path;

    if (renaming) {
      return _buildRenameInput(
        key: 'rename-folder-$path',
        value: state.renameValue,
        error: state.nameValidationError,
        depth: depth,
        icon: const FileIcon(
          'seti:folder',
          classes: 'file-tree-icon folder-icon',
        ),
        onChanged: actions.setRenameValue,
        onConfirm: () => actions.confirmRenameFolder(path),
        onCancel: actions.cancelRename,
      );
    }

    return div(
      key: ValueKey('folder-$path'),
      classes: [
        'file-tree-item folder',
        if (selected) 'selected',
        if (state.dropTargetFolder == path) 'drop-target',
        if (state.draggedFolder == path) 'dragging',
      ].join(' '),
      styles: Styles(raw: {'--tree-depth': '$depth'}),
      attributes: {
        'title': path,
        'tabindex': '0',
        'role': 'treeitem',
        'aria-expanded': collapsed ? 'false' : 'true',
        'draggable': protected || state.busy ? 'false' : 'true',
      },
      events: {
        'click': (event) {
          event.stopPropagation();
          actions.selectFolder(path);
        },
        'dblclick': (event) {
          event.stopPropagation();
          actions.toggleFolder(path);
        },
        'keydown': (event) {
          final keyboardEvent = event as web.KeyboardEvent;
          if (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ') {
            actions.toggleFolder(path);
          }
        },
        'dragstart': (event) {
          if (protected || state.busy) {
            event.preventDefault();
            return;
          }
          final dragEvent = event as web.DragEvent;
          dragEvent.dataTransfer?.setData('text/plain', path);
          dragEvent.dataTransfer?.effectAllowed = 'move';
          actions.startDraggingFolder(path);
        },
        'dragend': (_) => actions.finishDragging(),
        'dragover': (event) {
          event
            ..stopPropagation()
            ..preventDefault();
          actions.markDropTarget(path);
        },
        'dragleave': (event) {
          event.stopPropagation();
          actions.clearDropTarget(path);
        },
        'drop': (event) {
          event
            ..stopPropagation()
            ..preventDefault();
          unawaited(actions.dropIntoFolder(path));
        },
      },
      [
        button(
          classes: 'file-tree-disclosure',
          attributes: {
            'title': collapsed ? 'Expand' : 'Collapse',
            'aria-label': collapsed ? 'Expand $path' : 'Collapse $path',
          },
          events: {
            'click': (event) {
              event.stopPropagation();
              actions.toggleFolder(path);
            },
          },
          [
            if (node.children.isNotEmpty) disclosureIcon(expanded: !collapsed),
          ],
        ),
        const FileIcon(
          'seti:folder',
          classes: 'file-tree-icon folder-icon',
          attributes: {'aria-hidden': 'true'},
        ),
        span(classes: 'file-tree-name', [.text(node.resource.shortName)]),
        if (!protected)
          _rowActions(
            onRename: () => actions.startRenamingFolder(path),
            onDelete: () => _confirmDeleteFolder(path, state, actions),
          ),
      ],
    );
  }

  Component _buildFile(
    FileTreeFileNode node,
    FileTreeState state,
    FileTreeActions actions,
    int depth,
  ) {
    final path = node.resource.path;
    final protected = state.protectedEntries.contains(path);
    final openable = node.openable;
    final renaming = state.renamingFile == path;

    if (renaming) {
      return _buildRenameInput(
        key: 'rename-file-$path',
        value: state.renameValue,
        error: state.nameValidationError,
        depth: depth,
        icon: _fileIcon(node.resource.shortName),
        onChanged: actions.setRenameValue,
        onConfirm: () => actions.confirmRenameFile(path),
        onCancel: actions.cancelRename,
      );
    }

    return div(
      key: ValueKey('file-$path'),
      classes: [
        'file-tree-item file',
        if (state.activeFile == path) 'active',
        if (!openable) 'binary',
        if (state.draggedFile == path) 'dragging',
      ].join(' '),
      styles: Styles(raw: {'--tree-depth': '$depth'}),
      attributes: {
        'title': openable ? path : '$path — binary preview is not available',
        'tabindex': '0',
        'role': 'treeitem',
        'aria-disabled': openable ? 'false' : 'true',
        'draggable': protected || state.busy ? 'false' : 'true',
      },
      events: {
        'click': (event) {
          event.stopPropagation();
          actions.clearFolderSelection();
          if (openable) {
            unawaited(Future<void>.sync(() => actions.openFile(path)));
          }
        },
        'keydown': (event) {
          final keyboardEvent = event as web.KeyboardEvent;
          if (openable && (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ')) {
            unawaited(Future<void>.sync(() => actions.openFile(path)));
          }
        },
        'dragstart': (event) {
          if (protected || state.busy) {
            event.preventDefault();
            return;
          }
          final dragEvent = event as web.DragEvent;
          dragEvent.dataTransfer?.setData('text/plain', path);
          dragEvent.dataTransfer?.effectAllowed = 'move';
          actions.startDraggingFile(path);
        },
        'dragend': (_) => actions.finishDragging(),
      },
      [
        const span(classes: 'file-tree-disclosure spacer', []),
        _fileIcon(node.resource.shortName),
        span(classes: 'file-tree-name', [.text(node.resource.shortName)]),
        if (!protected)
          _rowActions(
            onRename: () => actions.startRenamingFile(path),
            onDelete: () => _confirmDeleteFile(path, state, actions),
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
        [pencilIcon()],
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
        [closeIcon()],
      ),
    ]);
  }

  Component _buildCreateInput(
    FileTreeState state,
    FileTreeActions actions,
    int depth,
  ) {
    final folder = state.creatingEntry == FileTreeEntryKind.folder;
    return div(
      key: ValueKey('create-${state.createTargetFolder}-${state.creatingEntry?.name}'),
      classes: 'file-tree-input-wrapper',
      styles: Styles(raw: {'--tree-depth': '$depth'}),
      [
        div(classes: 'file-tree-item input-row', [
          const span(classes: 'file-tree-disclosure spacer', []),
          folder
              ? const FileIcon(
                  'seti:folder',
                  classes: 'file-tree-icon folder-icon',
                )
              : const FileIcon(
                  'seti:default',
                  classes: 'file-tree-icon file-icon',
                ),
          input<String>(
            classes: 'file-tree-input${state.nameValidationError == null ? '' : ' invalid'}',
            value: state.newEntryName,
            attributes: {
              'data-role': 'new-tree-entry-input',
              'type': 'text',
              'placeholder': folder ? 'folder' : 'file',
              'spellcheck': 'false',
              'autocomplete': 'off',
            },
            onInput: actions.setNewEntryName,
            events: {
              'blur': (_) => unawaited(actions.handleCreateBlur()),
              'keydown': (event) {
                final keyboardEvent = event as web.KeyboardEvent;
                if (keyboardEvent.key == 'Enter' && state.nameValidationError == null) {
                  unawaited(folder ? actions.confirmAddFolder() : actions.confirmAddFile());
                } else if (keyboardEvent.key == 'Escape') {
                  actions.cancelCreate();
                }
              },
            },
          ),
          _confirmButton(
            enabled: state.nameValidationError == null,
            onConfirm: folder ? actions.confirmAddFolder : actions.confirmAddFile,
          ),
          _cancelButton(actions.cancelCreate),
        ]),
        if (state.nameValidationError case final error?) _validationError(error),
      ],
    );
  }

  Component _buildRenameInput({
    required String key,
    required String value,
    required String? error,
    required int depth,
    required Component icon,
    required void Function(String) onChanged,
    required Future<void> Function() onConfirm,
    required void Function() onCancel,
  }) {
    return div(
      key: ValueKey(key),
      classes: 'file-tree-input-wrapper',
      styles: Styles(raw: {'--tree-depth': '$depth'}),
      [
        div(classes: 'file-tree-item input-row', [
          const span(classes: 'file-tree-disclosure spacer', []),
          icon,
          input<String>(
            classes: 'file-tree-input${error == null ? '' : ' invalid'}',
            value: value,
            attributes: {
              'type': 'text',
              'autofocus': '',
              'spellcheck': 'false',
              'autocomplete': 'off',
            },
            onInput: onChanged,
            events: {
              'keydown': (event) {
                final keyboardEvent = event as web.KeyboardEvent;
                if (keyboardEvent.key == 'Enter' && error == null) {
                  unawaited(onConfirm());
                } else if (keyboardEvent.key == 'Escape') {
                  onCancel();
                }
              },
            },
          ),
          _confirmButton(enabled: error == null, onConfirm: onConfirm),
          _cancelButton(onCancel),
        ]),
        if (error != null) _validationError(error),
      ],
    );
  }

  Component _confirmButton({
    required bool enabled,
    required Future<void> Function() onConfirm,
  }) {
    return button(
      classes: 'file-tree-action confirm',
      attributes: {
        'title': 'Confirm',
        if (!enabled) 'disabled': '',
      },
      onClick: enabled ? () => unawaited(onConfirm()) : null,
      [successIcon()],
    );
  }

  Component _cancelButton(void Function() onCancel) {
    return button(
      classes: 'file-tree-action delete',
      attributes: {'title': 'Cancel'},
      onClick: onCancel,
      [closeIcon()],
    );
  }

  Component _validationError(String message) {
    return div(classes: 'file-tree-validation', [.text(message)]);
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
      attributes: const {'aria-hidden': 'true'},
    );
  }

  void _confirmDeleteFile(
    String path,
    FileTreeState state,
    FileTreeActions actions,
  ) {
    final dirty = state.dirtyEntries.contains(path);
    final message = dirty
        ? 'Delete "$path"? Its unsaved editor changes will be lost.'
        : 'Delete "$path"? This cannot be undone.';
    if (_confirmDelete(message)) {
      unawaited(actions.deleteFile(path));
    }
  }

  void _confirmDeleteFolder(
    String path,
    FileTreeState state,
    FileTreeActions actions,
  ) {
    final dirty = state.dirtyEntries.contains(path);
    final message = dirty
        ? 'Delete "$path" and all of its contents? Unsaved editor changes inside it will be lost.'
        : 'Delete "$path" and all of its contents? This cannot be undone.';
    if (_confirmDelete(message)) {
      unawaited(actions.deleteFolder(path));
    }
  }

  bool _confirmDelete(String message) {
    return component.confirmDelete?.call(message) ?? web.window.confirm(message);
  }

  void _scheduleCreateInputFocus(FileTreeState state) {
    final kind = state.creatingEntry;
    if (kind == null) {
      _scheduledFocusKey = null;
      return;
    }
    final key = '${kind.name}:${state.createTargetFolder}';
    if (_scheduledFocusKey == key) {
      return;
    }
    _scheduledFocusKey = key;
    scheduleMicrotask(() {
      Timer.run(() {
        final input = web.document.querySelector(_newEntryInputSelector) as web.HTMLInputElement?;
        input
          ?..focus()
          ..select();
      });
    });
  }
}
