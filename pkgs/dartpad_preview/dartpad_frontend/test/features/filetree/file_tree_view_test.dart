// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_models.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_view.dart';
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

  testClient('renders file metadata supplied by state', (tester) {
    tester.pumpComponent(
      FileTreeView(
        state: _state(workspace, openable: false),
        actions: _actions(),
      ),
    );

    final file = web.document.querySelector('.file-tree-item.file')!;
    expect(file.getAttribute('aria-disabled'), 'true');
    expect(file.classList.contains('binary'), isTrue);
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

  testClient('uses the injected delete confirmation callback', (tester) async {
    String? confirmationMessage;
    String? deletedPath;

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
      ),
    );

    final deleteButton =
        web.document.querySelector(
              '.file-tree-item.file [aria-label="Delete"]',
            )!
            as web.HTMLButtonElement;
    deleteButton.click();
    await pumpEventQueue();

    expect(confirmationMessage, contains('unsaved editor changes'));
    expect(deletedPath, 'example.txt');
  });
}

FileTreeState _state(
  WorkspaceResourceApi workspace, {
  bool openable = true,
  bool dirty = false,
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
    focusedPath: '',
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
    protectedEntries: const {},
    dirtyEntries: const {},
    focusedPath: '',
  );
}

FileTreeActions _actions({
  Future<void> Function(String path)? deleteFile,
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
    navigateUp: () {},
  );
}

Future<void> _noOpPathAsync(String _) async {}
