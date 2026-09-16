// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';
import 'package:web/web.dart' as web;

import '../../app_styles.dart';
import '../shared/components/context_menu.dart';
import '../shared/components/dropdown_menu.dart';
import '../shared/components/icon_button.dart';
import '../shared/components/split_panel.dart';
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
    this.contextMenu,
    super.key,
  });

  /// The file-tree state to render.
  final FileTreeState state;

  /// The actions invoked in response to user interaction.
  final FileTreeActions actions;

  /// An optional callback used to confirm destructive operations.
  final bool Function(String message)? confirmDelete;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  @override
  State<FileTreeView> createState() => _FileTreeViewInternalState();

  @css
  static List<StyleRule> get styles => _FileTreeViewInternalState.styles;
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

  void _startCreateFile() {
    setState(() {
      _creatingEntry = FileTreeEntryKind.file;
      _creatingInFolder = component.state.focusedPath;
      _selectedPath = null;
    });
  }

  void _startCreateFolder() {
    setState(() {
      _creatingEntry = FileTreeEntryKind.folder;
      _creatingInFolder = component.state.focusedPath;
      _selectedPath = null;
    });
  }

  @override
  Component build(BuildContext context) {
    final panel = SplitPanel.of(context);
    if (panel?.isPanelCollapsed ?? false) {
      return aside(classes: 'file-tree-rail', [
        IconButton(
          tooltip: 'Show file tree',
          label: 'Show file tree',
          icon: 'folder_open',
          iconSize: 18,
          onClick: (_) => panel?.expand(),
        ),
      ]);
    }

    final state = component.state;
    final actions = component.actions;
    final showCollapse = panel != null && panel.canCollapse;

    return aside(classes: 'file-tree', [
      div(classes: 'file-tree-header', [
        const span(classes: 'file-tree-title', [.text('Explorer')]),
        div(classes: 'file-tree-header-buttons', [
          DropdownMenu(
            disabled: state.busy,
            trigger: button(
              classes: 'file-tree-add-button',
              attributes: {
                'title': 'New file or folder',
                'aria-label': 'New file or folder',
                if (state.busy) 'disabled': 'true',
              },
              [const Icon('add', size: 16)],
            ),
            items: [
              DropdownMenuItem(
                label: 'New File',
                onPressed: _startCreateFile,
              ),
              DropdownMenuItem(
                label: 'New Folder',
                onPressed: _startCreateFolder,
              ),
            ],
          ),
          if (showCollapse)
            button(
              classes: 'file-tree-collapse-button',
              attributes: const {
                'title': 'Hide file tree',
                'aria-label': 'Hide file tree',
              },
              onClick: panel.collapse,
              [const Icon('chevron_left', size: 16)],
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
              unawaited(actions.moveEntry(sourcePath, state.focusedPath));
            }
          },
          'contextmenu': _handleContextMenu,
        },
        [
          if (_creatingEntry != null && _creatingInFolder == state.focusedPath)
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
                final targetPath = state.focusedPath.isEmpty ? name : '${state.focusedPath}/$name';
                if (state.root.exists(targetPath)) {
                  return 'A file or folder already exists at "$targetPath".';
                }
                return null;
              },
              onConfirm: (name) async {
                final kind = _creatingEntry!;
                final targetPath = state.focusedPath.isEmpty ? name : '${state.focusedPath}/$name';
                setState(() {
                  _creatingEntry = null;
                  _creatingInFolder = null;
                  _selectedPath = targetPath;
                });
                if (kind == FileTreeEntryKind.folder) {
                  await actions.createFolder(state.focusedPath, name);
                } else {
                  await actions.createFile(state.focusedPath, name);
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
                contextMenu: component.contextMenu,
                onStartCreate: (folderPath, kind) {
                  setState(() {
                    _creatingEntry = kind;
                    _creatingInFolder = folderPath;
                    _selectedPath = null;
                  });
                },
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
                contextMenu: component.contextMenu,
                confirmDelete: component.confirmDelete,
              );
            }
          }),
        ],
      ),
    ]);
  }

  void _handleContextMenu(web.Event event) {
    final menu = component.contextMenu;
    if (menu == null) {
      return;
    }
    final mouseEvent = event as web.MouseEvent;
    final target = mouseEvent.target as web.Element?;
    if (target?.closest('.file-tree-item') != null) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    menu.show(
      mouseEvent.clientX.toDouble(),
      mouseEvent.clientY.toDouble(),
      _buildContextMenuItems(),
    );
  }

  List<ContextMenuEntry> _buildContextMenuItems() {
    final state = component.state;
    return [
      ContextMenuItem(
        label: 'New file',
        disabled: state.busy,
        onPressed: _startCreateFile,
      ),
      ContextMenuItem(
        label: 'New folder',
        disabled: state.busy,
        onPressed: _startCreateFolder,
      ),
    ];
  }

  static List<StyleRule> get styles => [
    css('.file-tree-rail').styles(
      display: .flex,
      width: 36.px,
      minWidth: 36.px,
      padding: .only(top: 8.px),
      border: .only(
        right: .solid(color: colorBorder, width: 1.px),
      ),
      flexDirection: .column,
      alignItems: .center,
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.file-tree', [
      css('&').styles(
        display: .flex,
        height: 100.percent,
        minWidth: 100.px,
        minHeight: .zero,
        overflow: .hidden,
        flexDirection: .column,
        backgroundColor: colorContainer,
      ),
      css('.file-tree-header').styles(
        display: .flex,
        position: const .relative(),
        zIndex: const ZIndex(105),
        minHeight: 38.px,
        padding: .symmetric(horizontal: 10.px),
        border: .only(
          bottom: .solid(color: colorBorder, width: 1.px),
        ),
        justifyContent: .spaceBetween,
        alignItems: .center,
        backgroundColor: colorSurface,
      ),
      css('.file-tree-header-buttons').styles(
        display: .flex,
        alignItems: .center,
        gap: .all(2.px),
      ),
      css('.file-tree-title').styles(
        color: colorOnSurface,
        fontSize: 11.px,
        fontWeight: FontWeight.w600,
        textTransform: .upperCase,
        letterSpacing: 0.7.px,
      ),
      css('.file-tree-collapse-button, .file-tree-add-button, .file-tree-disclosure').styles(
        display: .flex,
        padding: .zero,
        border: .none,
        radius: .circular(4.px),
        cursor: .pointer,
        justifyContent: .center,
        alignItems: .center,
        color: colorOnSurface,
        backgroundColor: Colors.transparent,
      ),
      css('.file-tree-collapse-button, .file-tree-add-button').styles(width: 24.px, height: 24.px),
      css('.file-tree-collapse-button:hover, .file-tree-add-button:hover, .file-tree-disclosure:hover').styles(
        backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
      ),
      css('.file-tree-add-button:disabled').styles(
        opacity: 0.45,
        cursor: .defaultCursor,
      ),

      css('.file-tree-list', [
        css('&').styles(
          minHeight: .zero,
          overflow: .auto,
          flex: const Flex(grow: 1, basis: .zero),
        ),
        css('&.drop-target').styles(
          border: .none,
          outline: const Outline(style: .none),
          backgroundColor: const Color('#333333'),
        ),

        css('&.drop-target .file-tree-item').styles(
          backgroundColor: const Color('#333333'),
        ),
        css('&.busy').styles(cursor: .progress),
      ]),

      css('.file-tree-item', [
        css('&').styles(
          display: .flex,
          height: 25.px,
          padding: .only(
            left: const Unit.expression('calc(6px + var(--tree-depth) * 10px)'),
            right: 5.px,
          ),
          cursor: .pointer,
          userSelect: .none,
          alignItems: .center,
          gap: .all(5.px),
          color: colorOnContainer,
          fontSize: 12.px,
          backgroundColor: colorContainer,
        ),

        css('&:hover').styles(
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.05),
        ),
        css('&.active').styles(
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.1),
        ),
        css('&.dim .file-tree-name').styles(
          opacity: 0.4,
        ),
        css('&.folder').styles(
          position: const .sticky(
            top: .expression('calc(var(--tree-depth) * 25px)'),
          ),
          raw: {'z-index': 'calc(100 - var(--tree-depth))'},
        ),
        css('&.selected').styles(
          outline: Outline(
            color: colorPrimary,
            style: OutlineStyle.solid,
            width: OutlineWidth(1.px),
            offset: (-1).px,
          ),
          color: colorOnContainer,
          backgroundColor: colorContainer.highlight(colorPrimary, 0.4),
        ),

        css('&.dragging').styles(opacity: 0.45),
        css('&.binary').styles(opacity: 0.58, cursor: .defaultCursor),
      ]),

      css('.file-tree-folder').styles(position: const .relative()),
      css('.file-tree-list:hover .file-tree-folder:has(.file-tree-item.folder[aria-expanded=true])::after').styles(
        opacity: 1,
      ),
      css('.file-tree-folder::after').styles(
        content: '',
        display: .block,
        position: .absolute(
          left: const .expression('calc(14px + var(--tree-depth,0) * 10px)'),
          top: 22.px,
          bottom: 0.px,
        ),
        width: 1.px,
        opacity: 0,
        backgroundColor: colorContainer.highlight(colorOnContainer, 0.3),
        raw: {'z-index': 'calc(100 - var(--tree-depth) - 1)'},
      ),
      css(
        '.file-tree-folder:has(>.file-tree-item.selected, >.file-tree-folder-children >.file-tree-item.selected)::after',
      ).styles(
        backgroundColor: colorContainer.highlight(colorOnContainer, 0.5),
      ),
      css('.file-tree-folder.drop-target').styles(
        border: .none,
        outline: const Outline(style: .none),
        backgroundColor: colorContainer.highlight(colorOnContainer, 0.2),
      ),
      css('.file-tree-folder.drop-target .file-tree-item').styles(
        backgroundColor: colorContainer.highlight(colorOnContainer, 0.2),
      ),
      css('.file-tree-folder.drop-target > .file-tree-item *').styles(
        pointerEvents: .none,
      ),
      css('.file-tree-disclosure').styles(
        width: 16.px,
        height: 20.px,
        flex: const .shrink(0),
        fontSize: 16.px,
      ),
      css('.file-tree-disclosure.spacer').styles(pointerEvents: .none),
      css('.file-tree-icon').styles(
        width: 12.px,
        height: 12.px,
        flex: const .shrink(0),
        color: colorOnSurface,
        raw: const {'vertical-align': 'middle'},
      ),
      css('.file-tree-icon.file-icon-dart').styles(color: colorPrimary),
      css('.file-tree-icon.file-icon-yaml').styles(color: const Color('#c586c0')),
      css('.file-tree-name').styles(
        minWidth: .zero,
        overflow: .hidden,
        flex: const Flex(grow: 1, basis: .zero),
        textOverflow: .ellipsis,
        whiteSpace: .noWrap,
      ),
      css('.file-tree-input-wrapper').styles(
        position: const .relative(),
        raw: const {'z-index': '150'},
      ),
      css('.file-tree-input-container').styles(
        display: .flex,
        position: const .relative(),
        minWidth: .zero,
        flex: const Flex(grow: 1, basis: .zero),
      ),
      css('.file-tree-input', [
        css('&').styles(
          width: 100.percent,
          height: 20.px,
          minWidth: .zero,
          padding: .symmetric(horizontal: 4.px),
          boxSizing: .borderBox,
          border: .all(color: colorBorder, width: 1.px),
          radius: .circular(2.px),
          outline: const Outline(style: .none),
          color: colorOnContainer,
          fontSize: 1.em,
          backgroundColor: colorContainer,
        ),
        css('&.invalid').styles(
          border: .all(color: colorError, width: 1.px),
        ),
      ]),
      css('.file-tree-error').styles(
        padding: .symmetric(horizontal: 8.px, vertical: 5.px),
        color: colorError,
        fontSize: 11.px,
        backgroundColor: colorErrorSurface,
      ),
      css('.file-tree-validation').styles(
        position: const .absolute(
          top: Unit.expression('calc(100% - 1px)'),
          left: .zero,
          right: .zero,
        ),
        zIndex: const ZIndex(20),
        padding: .symmetric(horizontal: 6.px, vertical: 4.px),
        margin: .zero,
        boxSizing: .borderBox,
        border: .all(color: colorError, width: 1.px),
        radius: .only(bottomLeft: .circular(2.px), bottomRight: .circular(2.px)),
        color: colorOnContainer,
        fontSize: 11.px,
        backgroundColor: colorErrorSurface,
        raw: const {'line-height': '1.3', 'word-break': 'break-word'},
      ),
    ]),
  ];
}
