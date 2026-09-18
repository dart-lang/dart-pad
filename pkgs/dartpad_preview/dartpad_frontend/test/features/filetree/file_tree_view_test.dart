// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_models.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_view.dart';
import 'package:dartpad_frontend/features/shared/components/context_menu.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

final class _Workspace implements WorkspaceResourceApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Exercises the client-side file-tree rendering and interactions.
void main() {
  late WorkspaceResourceApi workspace;

  setUp(() {
    workspace = _Workspace();
  });

  testClient('renders file metadata and header title as Explorer', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace, openable: false),
        actions: _actions(),
      ),
    );

    final title = web.document.querySelector('.file-tree-title')!;
    expect(title.textContent, 'Explorer');

    final file = web.document.querySelector('.file-tree-item.file')!;
    expect(file.getAttribute('aria-disabled'), 'true');
    expect(file.classList.contains('binary'), isTrue);

    // Row hover action buttons and top toolbar are removed.
    expect(web.document.querySelector('.file-tree-actions'), isNull);
    expect(web.document.querySelector('.file-tree-toolbar'), isNull);
  });

  testClient('handles reported open failures from clicks and keyboard activation', (tester) async {
    var attempts = 0;
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          openWorkspaceFile: (_) async {
            attempts++;
            throw StateError('reported load failure');
          },
        ),
      ),
    );

    final file = web.document.querySelector('.file-tree-item.file')!;
    file.dispatchEvent(web.MouseEvent('click', web.MouseEventInit(bubbles: true)));
    await pumpEventQueue();
    file.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();
    expect(attempts, 2);
  });

  testClient('renders add button in header with foldable dropdown menu', (tester) async {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    expect(addButton, isNotNull);
    expect(addButton!.getAttribute('aria-label'), 'New file or folder');
    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);

    addButton.click();
    await pumpEventQueue();

    final panel = web.document.querySelector('.dropdown-menu-panel');
    expect(panel, isNotNull);

    final menuItems = web.document.querySelectorAll('.dropdown-menu-item');
    expect(menuItems.length, 2);
    expect(menuItems.item(0)!.textContent, 'New File');
    expect(menuItems.item(1)!.textContent, 'New Folder');
  });

  testClient('clicking "New File" in dropdown menu triggers file creation input', (tester) async {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    expect(newFileButton.textContent, 'New File');

    newFileButton.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);
    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);
    expect(input!.placeholder, 'file');
  });

  testClient('clicking "New Folder" in dropdown menu triggers folder creation input', (tester) async {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFolderButton = web.document.querySelectorAll('.dropdown-menu-item').item(1) as web.HTMLButtonElement;
    expect(newFolderButton.textContent, 'New Folder');

    newFolderButton.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);
    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);
    expect(input!.placeholder, 'folder');
  });

  testClient('add button is disabled when state is busy', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace, busy: true),
        actions: _actions(),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    expect(addButton, isNotNull);
    expect(addButton!.getAttribute('disabled'), isNotNull);
  });

  testClient('does not render collapse button in header when not in a collapsible SplitPanel', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(),
      ),
    );

    expect(web.document.querySelector('.file-tree-collapse-button'), isNull);
  });

  testClient('renders collapse button and collapses into rail when hosted in collapsible SplitPanel', (tester) async {
    tester.pumpComponent(
      SplitPanel(
        canCollapseLeft: true,
        left: FileTreeView(
          state: _state(workspace),
          actions: _actions(),
        ),
        right: const div([]),
      ),
    );

    final collapseButton =
        web.document.querySelector('.file-tree-header .file-tree-collapse-button') as web.HTMLButtonElement?;
    expect(collapseButton, isNotNull);
    expect(collapseButton!.getAttribute('aria-label'), 'Hide file tree');

    collapseButton.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.file-tree'), isNull);
    final railButton = web.document.querySelector('.file-tree-rail button') as web.HTMLButtonElement?;
    expect(railButton, isNotNull);
    expect(railButton!.getAttribute('aria-label'), 'Show file tree');

    railButton.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.file-tree'), isNotNull);
    expect(web.document.querySelector('.file-tree-rail'), isNull);
  });

  testClient('single click on a folder selects it and toggles collapsed state', (tester) async {
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(),
      ),
    );

    final folder = web.document.querySelector('.file-tree-item.folder')!;

    // The folder starts collapsed (aria-expanded="false") because it is not
    // 'lib' and not a parent of the active file.
    expect(folder.getAttribute('aria-expanded'), 'false');

    // A single click should expand the folder.
    (folder as web.HTMLElement).click();
    await pumpEventQueue();

    expect(folder.getAttribute('aria-expanded'), 'true');

    // A second click should collapse the folder again.
    folder.click();
    await pumpEventQueue();

    expect(folder.getAttribute('aria-expanded'), 'false');
  });

  testClient('uses the injected delete confirmation callback via context menu', (tester) async {
    String? confirmationMessage;
    String? deletedPath;
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace, dirty: true),
        actions: _actions(
          deleteFile: (path) async {
            deletedPath = path;
          },
        ),
        confirmDelete: (message) {
          confirmationMessage = message;
          return true;
        },
        contextMenu: contextMenu,
      ),
    );

    final file = web.document.querySelector('.file-tree-item.file') as web.HTMLElement;
    file.dispatchEvent(
      web.MouseEvent(
        'contextmenu',
        web.MouseEventInit(clientX: 100, clientY: 100, bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();

    expect(contextMenu.isOpen, isTrue);
    final deleteItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Delete',
    );
    deleteItem.onPressed();
    await pumpEventQueue();

    expect(confirmationMessage, contains('unsaved editor changes'));
    expect(deletedPath, 'example.txt');
  });

  testClient('folder context menu provides "Use as root" option', (tester) async {
    String? focusedPath;
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(
          focusPath: (path) {
            focusedPath = path;
          },
        ),
        contextMenu: contextMenu,
      ),
    );

    final folder = web.document.querySelector('.file-tree-item.folder') as web.HTMLElement;
    folder.dispatchEvent(
      web.MouseEvent(
        'contextmenu',
        web.MouseEventInit(clientX: 100, clientY: 100, bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();

    expect(contextMenu.isOpen, isTrue);
    final useAsRootItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Use as root',
    );
    useAsRootItem.onPressed();

    expect(focusedPath, 'src');
  });

  for (final focusedPath in ['', 'example', 'example/assets']) {
    testClient('tree background context menu offers creation actions at $focusedPath', (tester) async {
      final contextMenu = ContextMenuController();

      tester.pumpComponent(
        FileTreeView(
          state: _state(workspace, focusedPath: focusedPath, rootPath: focusedPath.isEmpty ? '' : 'example'),
          actions: _actions(),
          contextMenu: contextMenu,
        ),
      );

      final treeList = web.document.querySelector('.file-tree-list') as web.HTMLElement;
      treeList.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(clientX: 50, clientY: 50, bubbles: true, cancelable: true),
        ),
      );
      await pumpEventQueue();

      expect(contextMenu.isOpen, isTrue);
      expect(contextMenu.items.whereType<ContextMenuItem>().map((item) => item.label), ['New file', 'New folder']);
    });
  }

  testClient('file creation input does not render confirm or cancel buttons', (tester) async {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    newFileButton.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.file-tree-input'), isNotNull);
    expect(web.document.querySelector('.file-tree-action.confirm'), isNull);
    expect(web.document.querySelector('.file-tree-action.delete'), isNull);
  });

  testClient('pressing Enter when creation input is empty shows warning message and invalid style', (tester) async {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    newFileButton.click();
    await pumpEventQueue();

    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);
    expect(web.document.querySelector('.file-tree-validation'), isNull);
    expect(input!.classList.contains('invalid'), isFalse);

    input.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    final validation = web.document.querySelector('.file-tree-validation');
    expect(validation, isNotNull);
    expect(validation!.textContent, 'A name is required.');
    expect(input.classList.contains('invalid'), isTrue);
  });

  testClient('pressing Enter with valid name creates file and clears input', (tester) async {
    String? createdName;
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          createFile: (parent, name) async {
            createdName = name;
          },
        ),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    newFileButton.click();
    await pumpEventQueue();

    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);

    input!.value = 'new_component.dart';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    input.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    expect(createdName, 'new_component.dart');
    expect(web.document.querySelector('.file-tree-input'), isNull);
  });

  testClient('pressing Escape cancels creation regardless of input content', (tester) async {
    String? createdName;
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          createFile: (parent, name) async {
            createdName = name;
          },
        ),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    newFileButton.click();
    await pumpEventQueue();

    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);

    input!.value = 'abandoned_file.dart';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    input.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    expect(createdName, isNull);
    expect(web.document.querySelector('.file-tree-input'), isNull);
  });

  testClient('losing focus (blur) with valid name creates file', (tester) async {
    String? createdName;
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          createFile: (parent, name) async {
            createdName = name;
          },
        ),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    newFileButton.click();
    await pumpEventQueue();

    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);

    input!.value = 'confirmed_by_blur.dart';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    input.dispatchEvent(web.FocusEvent('blur', web.FocusEventInit(bubbles: true)));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await pumpEventQueue();

    expect(createdName, 'confirmed_by_blur.dart');
    expect(web.document.querySelector('.file-tree-input'), isNull);
  });

  testClient('losing focus (blur) with empty input cancels creation', (tester) async {
    String? createdName;
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          createFile: (parent, name) async {
            createdName = name;
          },
        ),
      ),
    );

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement?;
    addButton!.click();
    await pumpEventQueue();

    final newFileButton = web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement;
    newFileButton.click();
    await pumpEventQueue();

    final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement?;
    expect(input, isNotNull);

    input!.dispatchEvent(web.FocusEvent('blur', web.FocusEventInit(bubbles: true)));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await pumpEventQueue();

    expect(createdName, isNull);
    expect(web.document.querySelector('.file-tree-input'), isNull);
  });
}

FileTreeState _state(
  WorkspaceResourceApi workspace, {
  bool openable = true,
  bool dirty = false,
  String focusedPath = '',
  String rootPath = '',
  bool busy = false,
}) {
  const path = 'example.txt';
  return FileTreeState(
    root: FileTreeFolderNode(
      WorkspaceFolder(workspace: workspace, path: ''),
      children: [
        FileTreeFileNode(
          WorkspaceFile(workspace: workspace, path: path),
          openable: openable,
        ),
      ],
    ),
    activeFile: '',
    operationError: null,
    busy: busy,
    dirtyEntries: dirty ? const {path} : const {},
    focusedPath: focusedPath,
    rootPath: rootPath,
  );
}

FileTreeState _stateWithFolder(WorkspaceResourceApi workspace) {
  return FileTreeState(
    root: FileTreeFolderNode(
      WorkspaceFolder(workspace: workspace, path: ''),
      children: [
        FileTreeFolderNode(
          WorkspaceFolder(workspace: workspace, path: 'src'),
          children: [
            FileTreeFileNode(
              WorkspaceFile(workspace: workspace, path: 'src/utils.dart'),
              openable: true,
            ),
          ],
        ),
      ],
    ),
    activeFile: '',
    operationError: null,
    busy: false,
    dirtyEntries: const {},
    focusedPath: '',
  );
}

FileTreeActions _actions({
  Future<void> Function(String parentPath, String name)? createFile,
  Future<void> Function(String parentPath, String name)? createFolder,
  Future<void> Function(String path)? deleteFile,
  FutureOr<void> Function(String path)? openWorkspaceFile,
  void Function(String path)? focusPath,
}) {
  return FileTreeActions(
    createFile: createFile ?? (_, _) async {},
    createFolder: createFolder ?? (_, _) async {},
    renameFile: (_, _) async {},
    renameFolder: (_, _) async {},
    deleteFile: deleteFile ?? _noOpPathAsync,
    deleteFolder: _noOpPathAsync,
    moveEntry: (_, _) async {},
    openWorkspaceFile: openWorkspaceFile ?? _noOpPathAsync,
    clearOperationError: () {},
    focusPath: focusPath ?? (_) {},
  );
}

Future<void> _noOpPathAsync(String _) async {}
