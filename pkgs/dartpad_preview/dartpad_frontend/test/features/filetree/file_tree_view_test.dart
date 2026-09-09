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

  testClient('tree background context menu provides "Navigate up" when focused on a subfolder', (tester) async {
    var navigateUpCalled = false;
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace, focusedPath: 'subfolder'),
        actions: _actions(
          navigateUp: () {
            navigateUpCalled = true;
          },
        ),
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
    final navigateUpItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Navigate up',
    );
    navigateUpItem.onPressed();

    expect(navigateUpCalled, isTrue);
  });

  testClient('tree background context menu does not provide "Navigate up" at workspace root', (tester) async {
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace, focusedPath: ''),
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
    final hasNavigateUp = contextMenu.items.whereType<ContextMenuItem>().any(
      (item) => item.label == 'Navigate up',
    );
    expect(hasNavigateUp, isFalse);
  });

  testClient('does not render hidden files and folders when showHiddenFiles is false', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithHidden(workspace, showHiddenFiles: false),
        actions: _actions(),
      ),
    );

    expect(web.document.querySelector('.file-tree-item.folder[title=".dart_tool"]'), isNull);
    expect(web.document.querySelector('.file-tree-item.file[title=".env"]'), isNull);
    expect(web.document.querySelector('.file-tree-item.folder[title="src"]'), isNotNull);
    expect(web.document.querySelector('.file-tree-item.file[title="example.txt"]'), isNotNull);
  });

  testClient('renders hidden files and folders with dim class when showHiddenFiles is true', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithHidden(workspace, showHiddenFiles: true),
        actions: _actions(),
      ),
    );

    final hiddenFolder = web.document.querySelector('.file-tree-item.folder[title=".dart_tool"]');
    expect(hiddenFolder, isNotNull);
    expect(hiddenFolder!.classList.contains('dim'), isTrue);

    final hiddenFile = web.document.querySelector('.file-tree-item.file[title=".env"]');
    expect(hiddenFile, isNotNull);
    expect(hiddenFile!.classList.contains('dim'), isTrue);

    final visibleFolder = web.document.querySelector('.file-tree-item.folder[title="src"]');
    expect(visibleFolder, isNotNull);
    expect(visibleFolder!.classList.contains('dim'), isFalse);

    final visibleFile = web.document.querySelector('.file-tree-item.file[title="example.txt"]');
    expect(visibleFile, isNotNull);
    expect(visibleFile!.classList.contains('dim'), isFalse);
  });

  testClient('tree background context menu provides "Show hidden files" and toggles it', (tester) async {
    final contextMenu = ContextMenuController();
    var toggleCalled = false;

    tester.pumpComponent(
      FileTreeView(
        state: _stateWithHidden(workspace, showHiddenFiles: false),
        actions: _actions(
          toggleShowHiddenFiles: () {
            toggleCalled = true;
          },
        ),
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
    final showHiddenItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Show hidden files',
    );
    showHiddenItem.onPressed();

    expect(toggleCalled, isTrue);
  });

  testClient('tree background context menu provides "Hide hidden files" when showHiddenFiles is true', (tester) async {
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      FileTreeView(
        state: _stateWithHidden(workspace, showHiddenFiles: true),
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
    final hasHideHidden = contextMenu.items.whereType<ContextMenuItem>().any(
      (item) => item.label == 'Hide hidden files',
    );
    expect(hasHideHidden, isTrue);
  });

  testClient('folder context menu provides "Show hidden files"', (tester) async {
    final contextMenu = ContextMenuController();
    var toggleCalled = false;

    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(
          toggleShowHiddenFiles: () {
            toggleCalled = true;
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
    final showHiddenItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Show hidden files',
    );
    showHiddenItem.onPressed();

    expect(toggleCalled, isTrue);
  });

  testClient('file context menu provides "Show hidden files" and toggles it', (tester) async {
    final contextMenu = ContextMenuController();
    var toggleCalled = false;

    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          toggleShowHiddenFiles: () {
            toggleCalled = true;
          },
        ),
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
    final showHiddenItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Show hidden files',
    );
    showHiddenItem.onPressed();

    expect(toggleCalled, isTrue);
  });

  testClient('renders disclosure button with tabindex -1 for folder', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(),
      ),
    );

    final folder = web.document.querySelector('.file-tree-item.folder[title="src"]')!;
    final button = folder.querySelector('button.file-tree-disclosure');
    expect(button, isNotNull);
    expect(button!.getAttribute('tabindex'), '-1');
  });

  testClient('context menu "Show hidden files" is disabled when state is busy', (tester) async {
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      FileTreeView(
        state: FileTreeState(
          root: FileTreeFolderNode(
            WorkspaceFolder(workspace: workspace, path: ''),
          ),
          activeFile: '',
          operationError: null,
          busy: true,
          protectedEntries: const {},
          dirtyEntries: const {},
          focusedPath: '',
          showHiddenFiles: false,
        ),
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
    final showHiddenItem = contextMenu.items.whereType<ContextMenuItem>().firstWhere(
      (item) => item.label == 'Show hidden files',
    );
    expect(showHiddenItem.disabled, isTrue);
  });
}

FileTreeState _state(
  WorkspaceResourceApi workspace, {
  bool openable = true,
  bool dirty = false,
  String focusedPath = '',
  bool showHiddenFiles = false,
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
    busy: false,
    protectedEntries: const {},
    dirtyEntries: dirty ? const {path} : const {},
    focusedPath: focusedPath,
    showHiddenFiles: showHiddenFiles,
  );
}

FileTreeState _stateWithFolder(
  WorkspaceResourceApi workspace, {
  bool showHiddenFiles = false,
}) {
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
    protectedEntries: const {},
    dirtyEntries: const {},
    focusedPath: '',
    showHiddenFiles: showHiddenFiles,
  );
}

FileTreeState _stateWithHidden(WorkspaceResourceApi workspace, {bool showHiddenFiles = false}) {
  return FileTreeState(
    root: FileTreeFolderNode(
      WorkspaceFolder(workspace: workspace, path: ''),
      children: [
        FileTreeFolderNode(
          WorkspaceFolder(workspace: workspace, path: '.dart_tool'),
          isIgnored: true,
          children: [
            FileTreeFileNode(
              WorkspaceFile(workspace: workspace, path: '.dart_tool/package_config.json'),
              openable: true,
              isIgnored: true,
            ),
          ],
        ),
        FileTreeFolderNode(
          WorkspaceFolder(workspace: workspace, path: 'src'),
          children: [
            FileTreeFileNode(
              WorkspaceFile(workspace: workspace, path: 'src/utils.dart'),
              openable: true,
            ),
          ],
        ),
        FileTreeFileNode(
          WorkspaceFile(workspace: workspace, path: '.env'),
          openable: true,
          isIgnored: true,
        ),
        FileTreeFileNode(
          WorkspaceFile(workspace: workspace, path: 'example.txt'),
          openable: true,
        ),
      ],
    ),
    activeFile: '',
    operationError: null,
    busy: false,
    protectedEntries: const {},
    dirtyEntries: const {},
    focusedPath: '',
    showHiddenFiles: showHiddenFiles,
  );
}

FileTreeActions _actions({
  Future<void> Function(String path)? deleteFile,
  void Function(String path)? focusPath,
  void Function()? navigateUp,
  void Function()? toggleShowHiddenFiles,
}) {
  return FileTreeActions(
    createFile: (_, _) async {},
    createFolder: (_, _) async {},
    renameFile: (_, _) async {},
    renameFolder: (_, _) async {},
    deleteFile: deleteFile ?? _noOpPathAsync,
    deleteFolder: _noOpPathAsync,
    moveEntry: (_, _) async {},
    openFile: (_) {},
    clearOperationError: () {},
    navigateUp: navigateUp ?? () {},
    focusPath: focusPath ?? (_) {},
    toggleShowHiddenFiles: toggleShowHiddenFiles ?? () {},
  );
}

Future<void> _noOpPathAsync(String _) async {}
