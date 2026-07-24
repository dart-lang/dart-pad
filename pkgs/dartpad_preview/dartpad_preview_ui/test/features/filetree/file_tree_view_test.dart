// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_preview/features/filetree/file_tree_models.dart';
import 'package:dartpad_preview/features/filetree/file_tree_view.dart';
import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

final class _Workspace implements WorkspaceApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Exercises the client-side file-tree rendering and interactions.
void main() {
  late WorkspaceApi workspace;

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
  WorkspaceApi workspace, {
  bool openable = true,
  bool dirty = false,
}) {
  const path = 'example.txt';
  return FileTreeState(
    root: FileTreeFolderNode(
      WorkspaceFolder(workspace: workspace, path: ''),
      [
        FileTreeFileNode(
          WorkspaceFile(workspace: workspace, path: path),
          openable: openable,
        ),
      ],
    ),
    collapsedFolders: const {},
    selectedFolder: null,
    dropTargetFolder: null,
    draggedFile: null,
    draggedFolder: null,
    activeFile: '',
    creatingEntry: null,
    createTargetFolder: '',
    newEntryName: '',
    renamingFile: null,
    renamingFolder: null,
    renameValue: '',
    nameValidationError: null,
    operationError: null,
    busy: false,
    protectedEntries: const {},
    dirtyEntries: dirty ? const {path} : const {},
  );
}

FileTreeActions _actions({
  Future<void> Function(String path)? deleteFile,
}) {
  return FileTreeActions(
    setNewEntryName: (_) {},
    setRenameValue: (_) {},
    startAddingFile: () {},
    startAddingFolder: () {},
    handleCreateBlur: _noOpAsync,
    confirmAddFile: _noOpAsync,
    confirmAddFolder: _noOpAsync,
    cancelCreate: () {},
    startRenamingFile: (_) {},
    startRenamingFolder: (_) {},
    confirmRenameFile: _noOpPathAsync,
    confirmRenameFolder: _noOpPathAsync,
    cancelRename: () {},
    selectFolder: (_) {},
    toggleFolder: (_) {},
    clearFolderSelection: () {},
    startDraggingFile: (_) {},
    startDraggingFolder: (_) {},
    finishDragging: () {},
    markDropTarget: (_) {},
    clearDropTarget: (_) {},
    dropIntoFolder: _noOpPathAsync,
    openFile: (_) {},
    deleteFile: deleteFile ?? _noOpPathAsync,
    deleteFolder: _noOpPathAsync,
  );
}

Future<void> _noOpAsync() async {}

Future<void> _noOpPathAsync(String _) async {}
