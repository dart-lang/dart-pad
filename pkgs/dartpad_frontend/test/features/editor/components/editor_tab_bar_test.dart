// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/components/editor_tab_bar.dart';
import 'package:dartpad_frontend/features/shared/components/context_menu.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

final class _TestEditorTab extends EditorTab<Component> {
  _TestEditorTab(super.path, {this.unsaved = false});

  final bool unsaved;

  @override
  Component build() => const Component.fragment([]);

  @override
  void discardUnsavedChanges() {}

  @override
  bool get hasUnsavedChanges => unsaved;

  @override
  bool get keepAlive => false;

  @override
  Stream<void> get onUpdate => const Stream.empty();

  @override
  Future<void> save() async {}
}

void main() {
  group('EditorTabBar – batch close cancellation', () {
    testClient('closeAllTabs aborts immediately when user cancels discard on a dirty tab', (tester) async {
      final contextMenu = ContextMenuController();
      final tab1 = _TestEditorTab('lib/a.dart', unsaved: true);
      final tab2 = _TestEditorTab('lib/b.dart', unsaved: true);
      final tab3 = _TestEditorTab('lib/c.dart', unsaved: false);

      final closedPaths = <String>[];
      final promptedPaths = <String>[];

      tester.pumpComponent(
        div([
          EditorTabBar(
            openTabs: [tab1, tab2, tab3],
            activeFile: 'lib/a.dart',
            onSwitchFile: (_) {},
            onCloseFile: (path, {discardChanges = false}) {
              closedPaths.add(path);
              return true;
            },
            confirmDiscard: (path) {
              promptedPaths.add(path);
              return false; // User cancels confirmation dialog
            },
            contextMenu: contextMenu,
          ),
          ListenableBuilder(
            listenable: contextMenu,
            builder: (context) => contextMenu.isOpen
                ? ContextMenu(
                    x: contextMenu.x,
                    y: contextMenu.y,
                    items: contextMenu.items,
                    onClose: contextMenu.hide,
                  )
                : const Component.fragment([]),
          ),
        ]),
      );

      final tabBar = web.document.querySelector('.editor-tab-bar') as web.HTMLElement;
      tabBar.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(clientX: 10, clientY: 10, bubbles: true, cancelable: true),
        ),
      );
      await pumpEventQueue();

      expect(contextMenu.isOpen, isTrue);
      final closeAllItem =
          contextMenu.items.firstWhere(
                (item) => item is ContextMenuItem && item.label == 'Close all tabs',
              )
              as ContextMenuItem;

      closeAllItem.onPressed();

      // Only tab1 was prompted, then the batch aborted because user clicked cancel
      expect(promptedPaths, ['lib/a.dart']);
      expect(closedPaths, isEmpty);
    });

    testClient('closeOtherTabs aborts when user cancels discard on dirty tab', (tester) async {
      final contextMenu = ContextMenuController();
      final tab1 = _TestEditorTab('lib/keep.dart', unsaved: false);
      final tab2 = _TestEditorTab('lib/dirty1.dart', unsaved: true);
      final tab3 = _TestEditorTab('lib/dirty2.dart', unsaved: true);

      final closedPaths = <String>[];
      final promptedPaths = <String>[];

      tester.pumpComponent(
        EditorTabBar(
          openTabs: [tab1, tab2, tab3],
          activeFile: 'lib/keep.dart',
          onSwitchFile: (_) {},
          onCloseFile: (path, {discardChanges = false}) {
            closedPaths.add(path);
            return true;
          },
          confirmDiscard: (path) {
            promptedPaths.add(path);
            return false;
          },
          contextMenu: contextMenu,
        ),
      );

      final firstTab = web.document.querySelector('.editor-tab') as web.HTMLElement;
      firstTab.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(clientX: 10, clientY: 10, bubbles: true, cancelable: true),
        ),
      );
      await pumpEventQueue();

      final closeOthersItem =
          contextMenu.items.firstWhere(
                (item) => item is ContextMenuItem && item.label == 'Close others',
              )
              as ContextMenuItem;

      closeOthersItem.onPressed();

      expect(promptedPaths, ['lib/dirty1.dart']);
      expect(closedPaths, isEmpty);
    });

    testClient('closeAllTabs continues closing all tabs if user confirms each discard', (tester) async {
      final contextMenu = ContextMenuController();
      final tab1 = _TestEditorTab('lib/a.dart', unsaved: true);
      final tab2 = _TestEditorTab('lib/b.dart', unsaved: false);
      final tab3 = _TestEditorTab('lib/c.dart', unsaved: true);

      final closedPaths = <String>[];
      final promptedPaths = <String>[];

      tester.pumpComponent(
        EditorTabBar(
          openTabs: [tab1, tab2, tab3],
          activeFile: 'lib/a.dart',
          onSwitchFile: (_) {},
          onCloseFile: (path, {discardChanges = false}) {
            closedPaths.add(path);
            return true;
          },
          confirmDiscard: (path) {
            promptedPaths.add(path);
            return true; // User confirms discard
          },
          contextMenu: contextMenu,
        ),
      );

      final firstTab = web.document.querySelector('.editor-tab') as web.HTMLElement;
      firstTab.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(clientX: 10, clientY: 10, bubbles: true, cancelable: true),
        ),
      );
      await pumpEventQueue();

      final closeAllItem =
          contextMenu.items.firstWhere(
                (item) => item is ContextMenuItem && item.label == 'Close all',
              )
              as ContextMenuItem;

      closeAllItem.onPressed();

      expect(promptedPaths, ['lib/a.dart', 'lib/c.dart']);
      expect(closedPaths, ['lib/a.dart', 'lib/b.dart', 'lib/c.dart']);
    });
  });

  group('EditorTabBar – layout and dirty indicator structure', () {
    testClient('tabs have consistent top-level child count whether clean or dirty', (tester) async {
      final cleanTab = _TestEditorTab('lib/clean.dart', unsaved: false);
      final dirtyTab = _TestEditorTab('lib/dirty.dart', unsaved: true);

      tester.pumpComponent(
        EditorTabBar(
          openTabs: [cleanTab, dirtyTab],
          activeFile: 'lib/clean.dart',
          onSwitchFile: (_) {},
          onCloseFile: (_, {discardChanges = false}) => true,
        ),
      );

      final tabElements = web.document.querySelectorAll('.editor-tab');
      expect(tabElements.length, 2);

      final cleanElement = tabElements.item(0)! as web.HTMLElement;
      final dirtyElement = tabElements.item(1)! as web.HTMLElement;

      // Both tabs have exactly 2 direct children: .editor-tab-name and .editor-tab-action
      expect(cleanElement.children.length, 2);
      expect(dirtyElement.children.length, 2);

      expect(cleanElement.children.item(0)!.className, contains('editor-tab-name'));
      expect(cleanElement.children.item(1)!.className, contains('editor-tab-action'));

      expect(dirtyElement.children.item(0)!.className, contains('editor-tab-name'));
      expect(dirtyElement.children.item(1)!.className, contains('editor-tab-action'));

      // Dirty dot is contained inside the action button for dirty tabs
      final dirtyAction = dirtyElement.querySelector('.editor-tab-action') as web.HTMLElement;
      expect(dirtyAction.className, contains('dirty'));
      expect(dirtyAction.querySelector('.editor-tab-dirty-dot'), isNotNull);
      expect(dirtyAction.querySelector('.material-symbols-outlined'), isNotNull);

      // Clean tab does not contain dirty dot
      final cleanAction = cleanElement.querySelector('.editor-tab-action') as web.HTMLElement;
      expect(cleanAction.className, isNot(contains('dirty')));
      expect(cleanAction.querySelector('.editor-tab-dirty-dot'), isNull);
    });
  });
}
