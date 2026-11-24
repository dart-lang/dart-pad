// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_models.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_view.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('revealing the active file scrolls only the file tree', (tester) async {
    tester.pumpComponent(const _ScrollFixture());
    await pumpEventQueue();
    final host = web.document.getElementById('scroll-host')!;
    final tree = web.document.querySelector('.file-tree-list')!;
    host.scrollTop = 220;
    tree.scrollTop = 0;
    final hostScroll = host.scrollTop;

    (web.document.getElementById('switch-file')! as web.HTMLElement).click();
    await pumpEventQueue();

    expect(host.scrollTop, hostScroll, reason: 'Revealing an Explorer row must not scroll its ancestors.');
    expect(tree.scrollTop, greaterThan(0), reason: 'The active file must still be revealed inside the tree.');
    final row = web.document.querySelector('.file-tree-item.file[title="lib/file35.dart"]')!;
    final bounds = tree.getBoundingClientRect();
    final rowBounds = row.getBoundingClientRect();
    expect(rowBounds.top, closeTo(bounds.top + tree.clientTop + 25, 1));
    expect(rowBounds.bottom, lessThanOrEqualTo(bounds.bottom));
  });

  testClient('creating a folder keeps the enclosing page at its scroll position', (tester) async {
    tester.pumpComponent(const _ScrollFixture());
    await pumpEventQueue();
    (web.document.querySelector('.file-tree-item.folder')! as web.HTMLElement).click();
    await pumpEventQueue();
    final host = web.document.getElementById('scroll-host')!;
    host.scrollTop = 220;
    final hostScroll = host.scrollTop;

    (web.document.querySelector('.file-tree-add-button')! as web.HTMLElement).click();
    await pumpEventQueue();
    (web.document.querySelectorAll('.dropdown-menu-item').item(1)! as web.HTMLElement).click();
    await pumpEventQueue();

    final input = web.document.querySelector('.file-tree-folder-children .file-tree-input')!;
    expect(web.document.activeElement, input);
    expect(host.scrollTop, hostScroll, reason: 'Showing and focusing the folder input must not scroll its ancestors.');
  });

  for (final (kind, menuIndex) in [('file', 0), ('folder', 1)]) {
    testClient('creating a root $kind reveals its input in a scrolled tree', (tester) async {
      tester.pumpComponent(const _ScrollFixture());
      await pumpEventQueue();
      final host = web.document.getElementById('scroll-host')!;
      final tree = web.document.querySelector('.file-tree-list')!;
      host.scrollTop = 220;
      tree.scrollTop = 250;
      final hostScroll = host.scrollTop;
      expect(tree.scrollTop, greaterThan(0));

      (web.document.querySelector('.file-tree-add-button')! as web.HTMLElement).click();
      await pumpEventQueue();
      (web.document.querySelectorAll('.dropdown-menu-item').item(menuIndex)! as web.HTMLElement).click();
      await pumpEventQueue();

      final input = web.document.querySelector('.file-tree-input')!;
      final inputRect = input.getBoundingClientRect();
      final treeRect = tree.getBoundingClientRect();
      expect(web.document.activeElement, input);
      expect(inputRect.top, greaterThanOrEqualTo(treeRect.top));
      expect(inputRect.bottom, lessThanOrEqualTo(treeRect.bottom));
      expect(host.scrollTop, hostScroll, reason: 'Revealing the input must not scroll the enclosing page.');
    });
  }

  for (final (kind, menuIndex) in [('file', 0), ('folder', 1)]) {
    testClient('creating a nested $kind reveals its input in a scrolled tree', (tester) async {
      tester.pumpComponent(const _ScrollFixture());
      await pumpEventQueue();
      (web.document.querySelector('.file-tree-item.folder')! as web.HTMLElement).click();
      await pumpEventQueue();
      (web.document.querySelector('.file-tree-item.folder')! as web.HTMLElement).click();
      await pumpEventQueue();
      final host = web.document.getElementById('scroll-host')!;
      final tree = web.document.querySelector('.file-tree-list')!;
      host.scrollTop = 220;
      tree.scrollTop = 250;
      final hostScroll = host.scrollTop;
      expect(tree.scrollTop, greaterThan(0));

      (web.document.querySelector('.file-tree-add-button')! as web.HTMLElement).click();
      await pumpEventQueue();
      (web.document.querySelectorAll('.dropdown-menu-item').item(menuIndex)! as web.HTMLElement).click();
      await pumpEventQueue();

      final input = web.document.querySelector('.file-tree-folder-children .file-tree-input')!;
      expect(web.document.activeElement, input);
      expect(input.getBoundingClientRect().top, greaterThanOrEqualTo(tree.getBoundingClientRect().top));
      expect(input.getBoundingClientRect().bottom, lessThanOrEqualTo(tree.getBoundingClientRect().bottom));
      expect(host.scrollTop, hostScroll, reason: 'Revealing the input must not scroll the enclosing page.');
    });
  }
}

final class _Workspace implements WorkspaceResourceApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScrollFixture extends StatefulComponent {
  const _ScrollFixture();

  @override
  State<_ScrollFixture> createState() => _ScrollFixtureState();
}

class _ScrollFixtureState extends State<_ScrollFixture> {
  final workspace = _Workspace();
  String activeFile = 'lib/file00.dart';

  @override
  Component build(BuildContext context) {
    return div([
      Style(styles: FileTreeView.styles),
      div(
        id: 'scroll-host',
        styles: Styles(height: 300.px, overflow: .auto),
        [
          div(styles: Styles(height: 260.px), []),
          button(
            id: 'switch-file',
            events: {'click': (_) => setState(() => activeFile = 'lib/file35.dart')},
            const [.text('Switch active file')],
          ),
          div(
            styles: Styles(width: 240.px, height: 180.px),
            [
              FileTreeView(
                state: FileTreeState(
                  root: FileTreeFolderNode(
                    WorkspaceFolder(workspace: workspace, path: ''),
                    children: [
                      FileTreeFolderNode(
                        WorkspaceFolder(workspace: workspace, path: 'lib'),
                        children: [
                          for (var i = 0; i < 40; i++)
                            FileTreeFileNode(
                              WorkspaceFile(workspace: workspace, path: 'lib/file${i.toString().padLeft(2, '0')}.dart'),
                              openable: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                  activeFile: activeFile,
                  operationError: null,
                  busy: false,
                  dirtyEntries: const {},
                  focusedPath: '',
                ),
                actions: FileTreeActions(
                  createFile: (_, _) async => true,
                  createFolder: (_, _) async {},
                  renameFile: (_, _) async {},
                  renameFolder: (_, _) async {},
                  deleteFile: (_) async {},
                  deleteFolder: (_) async {},
                  moveEntry: (_, _) async {},
                  openWorkspaceFile: (_) async {},
                  clearOperationError: () {},
                  focusPath: (_) {},
                ),
              ),
            ],
          ),
          div(styles: Styles(height: 800.px), []),
        ],
      ),
    ]);
  }
}
