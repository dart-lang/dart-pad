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
      [
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
  );
}

Future<void> _noOpPathAsync(String _) async {}
