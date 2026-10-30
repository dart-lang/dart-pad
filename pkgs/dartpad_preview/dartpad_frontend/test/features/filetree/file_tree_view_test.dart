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
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

import '../../split_panel_fixture.dart';

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
    var opened = 0;
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace),
        actions: _actions(
          openWorkspaceFile: (_) async {
            attempts++;
            throw StateError('reported load failure');
          },
        ),
        onFileOpened: () => opened++,
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
    expect(opened, 0);
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

  testClient('header "New File" creates the file in the root when nothing is selected', (tester) async {
    final created = <(String, String)>[];
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(createFile: (parent, name) async => created.add((parent, name))),
      ),
    );

    await _createViaHeaderMenu(itemIndex: 0, name: 'main.dart');

    expect(created, [('', 'main.dart')]);
  });

  testClient('header "New File" creates the file in the selected folder', (tester) async {
    final created = <(String, String)>[];
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(createFile: (parent, name) async => created.add((parent, name))),
      ),
    );

    (web.document.querySelector('.file-tree-item.folder') as web.HTMLElement).click();
    await pumpEventQueue();

    final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement;
    addButton.click();
    await pumpEventQueue();
    (web.document.querySelectorAll('.dropdown-menu-item').item(0) as web.HTMLButtonElement).click();
    await pumpEventQueue();

    // The input is rendered inside the selected folder, not at the tree root.
    expect(web.document.querySelector('.file-tree-folder-children .file-tree-input'), isNotNull);

    await _confirmCreationInput('widget.dart');

    expect(created, [('src', 'widget.dart')]);
  });

  testClient('header "New Folder" creates the folder next to the selected file', (tester) async {
    final created = <(String, String)>[];
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(createFolder: (parent, name) async => created.add((parent, name))),
      ),
    );

    // Expand 'src' and select the file inside it.
    (web.document.querySelector('.file-tree-item.folder') as web.HTMLElement).click();
    await pumpEventQueue();
    (web.document.querySelector('.file-tree-item.file') as web.HTMLElement).click();
    await pumpEventQueue();

    await _createViaHeaderMenu(itemIndex: 1, name: 'models');

    expect(created, [('src', 'models')]);
  });

  testClient('tree background context menu creates in the root while a folder is selected', (tester) async {
    final created = <(String, String)>[];
    final contextMenu = ContextMenuController();
    tester.pumpComponent(
      FileTreeView(
        state: _stateWithFolder(workspace),
        actions: _actions(createFile: (parent, name) async => created.add((parent, name))),
        contextMenu: contextMenu,
      ),
    );

    (web.document.querySelector('.file-tree-item.folder') as web.HTMLElement).click();
    await pumpEventQueue();

    (web.document.querySelector('.file-tree-list') as web.HTMLElement).dispatchEvent(
      web.MouseEvent(
        'contextmenu',
        web.MouseEventInit(clientX: 50, clientY: 50, bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();

    contextMenu.items.whereType<ContextMenuItem>().firstWhere((item) => item.label == 'New file').onPressed();
    await pumpEventQueue();

    await _confirmCreationInput('notes.md');

    expect(created, [('', 'notes.md')]);
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
      withSplitOwner(
        tester,
        const Split(0.5),
        (state, onChanged) => SplitPanel(
          state: state,
          onStateChanged: onChanged,
          canCollapseLeft: true,
          left: FileTreeView(
            state: _state(workspace),
            actions: _actions(),
          ),
          right: const div([]),
        ),
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

  web.KeyboardEvent deleteKeyEvent(_Platform platform) {
    return switch (platform) {
      _Platform.macOS => web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Backspace', metaKey: true, bubbles: true, cancelable: true),
      ),
      _Platform.windows => web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Delete', bubbles: true, cancelable: true),
      ),
    };
  }

  for (final platform in _Platform.values) {
    testClient(
      'delete shortcut fires delete confirmation on ${platform.name}',
      skip: platform != _hostPlatform,
      (tester) async {
        var confirmCalls = 0;
        String? confirmationMessage;

        tester.pumpComponent(
          FileTreeView(
            state: _state(workspace),
            actions: _actions(),
            confirmDelete: (message) {
              confirmCalls++;
              confirmationMessage = message;
              return false;
            },
          ),
        );

        final file = web.document.querySelector('.file-tree-item.file') as web.HTMLElement;
        file.dispatchEvent(deleteKeyEvent(platform));
        await pumpEventQueue();

        expect(confirmCalls, 1);
        expect(confirmationMessage, contains('This cannot be undone.'));
      },
    );
  }

  for (final platform in _Platform.values) {
    testClient(
      'deletes the focused file on shortcut after confirmation on ${platform.name}',
      skip: platform != _hostPlatform,
      (tester) async {
        String? deletedPath;

        tester.pumpComponent(
          FileTreeView(
            state: _state(workspace),
            actions: _actions(
              deleteFile: (path) async {
                deletedPath = path;
              },
            ),
            confirmDelete: (_) => true,
          ),
        );

        final file = web.document.querySelector('.file-tree-item.file') as web.HTMLElement;
        file.dispatchEvent(deleteKeyEvent(platform));
        await pumpEventQueue();

        expect(deletedPath, 'example.txt');
      },
    );
  }

  final renameEntries = {
    'file': (rowSelector: '.file-tree-item.file', buildState: _state),
    'folder': (rowSelector: '.file-tree-item.folder', buildState: _stateWithFolder),
  };
  for (final entry in renameEntries.entries) {
    for (final platform in _Platform.values) {
      testClient(
        'delete shortcut does not delete ${entry.key} while renaming it on ${platform.name}',
        skip: platform != _hostPlatform,
        (tester) async {
          var confirmCalls = 0;
          String? deletedPath;
          final contextMenu = ContextMenuController();

          tester.pumpComponent(
            FileTreeView(
              state: entry.value.buildState(workspace),
              actions: _actions(
                deleteFile: (path) async {
                  deletedPath = path;
                },
                deleteFolder: (path) async {
                  deletedPath = path;
                },
              ),
              confirmDelete: (_) {
                confirmCalls++;
                return true;
              },
              contextMenu: contextMenu,
            ),
          );

          final row = web.document.querySelector(entry.value.rowSelector) as web.HTMLElement;
          row.dispatchEvent(
            web.MouseEvent(
              'contextmenu',
              web.MouseEventInit(clientX: 100, clientY: 100, bubbles: true, cancelable: true),
            ),
          );
          await pumpEventQueue();
          contextMenu.items.whereType<ContextMenuItem>().firstWhere((item) => item.label == 'Rename').onPressed();
          await pumpEventQueue();

          final input = web.document.querySelector('.file-tree-input') as web.HTMLElement?;
          expect(input, isNotNull);
          input!.dispatchEvent(deleteKeyEvent(platform));
          await pumpEventQueue();

          expect(confirmCalls, 0);
          expect(deletedPath, isNull);
        },
      );
    }
  }

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

  testClient('does not render ignored files and folders', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: FileTreeState(
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
                WorkspaceFolder(workspace: workspace, path: 'lib'),
                children: [
                  FileTreeFileNode(
                    WorkspaceFile(workspace: workspace, path: 'lib/main.dart'),
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
                WorkspaceFile(workspace: workspace, path: 'pubspec.yaml'),
                openable: true,
              ),
            ],
          ),
          activeFile: '',
          operationError: null,
          busy: false,
          dirtyEntries: const {},
          focusedPath: '',
        ),
        actions: _actions(),
      ),
    );

    expect(web.document.querySelector('.file-tree-item.folder[title=".dart_tool"]'), isNull);
    expect(web.document.querySelector('.file-tree-item.file[title=".env"]'), isNull);
    expect(web.document.querySelector('.file-tree-item.folder[title="lib"]'), isNotNull);
    expect(web.document.querySelector('.file-tree-item.file[title="pubspec.yaml"]'), isNotNull);
  });
}

/// Opens the header "New file or folder" menu, picks [itemIndex], and confirms
/// the creation input with [name].
Future<void> _createViaHeaderMenu({
  required int itemIndex,
  required String name,
}) async {
  final addButton = web.document.querySelector('.file-tree-header .file-tree-add-button') as web.HTMLButtonElement;
  addButton.click();
  await pumpEventQueue();

  (web.document.querySelectorAll('.dropdown-menu-item').item(itemIndex) as web.HTMLButtonElement).click();
  await pumpEventQueue();

  await _confirmCreationInput(name);
}

/// Types [name] into the open creation input and confirms it with Enter.
Future<void> _confirmCreationInput(String name) async {
  final input = web.document.querySelector('.file-tree-input') as web.HTMLInputElement;
  input.value = name;
  input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
  await pumpEventQueue();

  input.dispatchEvent(
    web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true)),
  );
  await pumpEventQueue();
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
  Future<void> Function(String path)? deleteFolder,
  FutureOr<void> Function(String path)? openWorkspaceFile,
  void Function(String path)? focusPath,
}) {
  return FileTreeActions(
    createFile: createFile ?? (_, _) async {},
    createFolder: createFolder ?? (_, _) async {},
    renameFile: (_, _) async {},
    renameFolder: (_, _) async {},
    deleteFile: deleteFile ?? _noOpPathAsync,
    deleteFolder: deleteFolder ?? _noOpPathAsync,
    moveEntry: (_, _) async {},
    openWorkspaceFile: openWorkspaceFile ?? _noOpPathAsync,
    clearOperationError: () {},
    focusPath: focusPath ?? (_) {},
  );
}

enum _Platform { macOS, windows }

final _hostPlatform = isMac ? _Platform.macOS : _Platform.windows;

Future<void> _noOpPathAsync(String _) async {}
