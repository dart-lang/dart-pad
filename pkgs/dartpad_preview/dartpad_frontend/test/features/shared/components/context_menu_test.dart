// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/console_panel.dart';
import 'package:dartpad_frontend/features/editor/components/editor_tab_bar.dart';
import 'package:dartpad_frontend/features/shared/components/context_menu.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

void main() {
  group('ContextMenuController', () {
    test('opens and closes correctly', () {
      final controller = ContextMenuController();
      expect(controller.isOpen, isFalse);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.show(100, 200, [
        ContextMenuItem(label: 'Item 1', onPressed: () {}),
      ]);

      expect(controller.isOpen, isTrue);
      expect(controller.x, 100);
      expect(controller.y, 200);
      expect(controller.items.length, 1);
      expect(notified, isTrue);

      notified = false;
      controller.hide();
      expect(controller.isOpen, isFalse);
      expect(controller.items, isEmpty);
      expect(notified, isTrue);
    });

    test('calling show with empty items closes the menu', () {
      final controller = ContextMenuController();
      controller.show(100, 200, [ContextMenuItem(label: 'A', onPressed: () {})]);
      expect(controller.isOpen, isTrue);

      controller.show(100, 200, []);
      expect(controller.isOpen, isFalse);
    });

    test('calling show and hide on disposed controller does not throw', () {
      final controller = ContextMenuController()..dispose();

      expect(
        () => controller.show(100, 200, [ContextMenuItem(label: 'A', onPressed: () {})]),
        returnsNormally,
      );
      expect(controller.isOpen, isFalse);

      expect(controller.hide, returnsNormally);
      expect(controller.isOpen, isFalse);
    });
  });

  group('ContextMenu Component', () {
    testClient('renders menu items, shortcuts and dividers', (tester) async {
      var item1Clicked = false;

      tester.pumpComponent(
        ContextMenu(
          x: 50,
          y: 50,
          onClose: () {},
          items: [
            ContextMenuItem(
              label: 'Cut',
              shortcut: 'Ctrl+X',
              onPressed: () => item1Clicked = true,
            ),
            const ContextMenuItem(
              label: 'Disabled Item',
              disabled: true,
              onPressed: _noop,
            ),
            const ContextMenuDivider(),
            ContextMenuItem(
              label: 'Delete',
              destructive: true,
              onPressed: () {},
            ),
          ],
        ),
      );

      final menu = web.document.querySelector('.context-menu');
      expect(menu, isNotNull);

      // Divider
      final divider = menu?.querySelector('.context-menu-divider');
      expect(divider, isNotNull);

      // Menu items
      final items = menu?.querySelectorAll('.context-menu-item');
      expect(items?.length, 3);

      final firstItem = items?.item(0) as web.HTMLButtonElement?;
      expect(firstItem?.textContent, contains('Cut'));
      expect(firstItem?.textContent, contains('Ctrl+X'));

      final disabledItem = items?.item(1) as web.HTMLButtonElement?;
      expect(disabledItem?.disabled, isTrue);

      final destructiveItem = items?.item(2) as web.HTMLButtonElement?;
      expect(destructiveItem?.className, contains('destructive'));

      // Click item
      firstItem?.click();
      expect(item1Clicked, isTrue);
    });

    testClient('invokes onClose when clicking an item', (tester) async {
      var closed = false;
      var clicked = false;

      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () => closed = true,
          items: [
            ContextMenuItem(
              label: 'Option 1',
              onPressed: () => clicked = true,
            ),
          ],
        ),
      );

      final button = web.document.querySelector('.context-menu-item') as web.HTMLButtonElement?;
      button?.click();
      await pumpEventQueue();

      expect(clicked, isTrue);
      expect(closed, isTrue);
    });

    testClient('invokes onClose on Escape keydown', (tester) async {
      var closed = false;

      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () => closed = true,
          items: [
            ContextMenuItem(label: 'Action', onPressed: () {}),
          ],
        ),
      );

      await pumpEventQueue();

      web.document.dispatchEvent(
        web.KeyboardEvent(
          'keydown',
          web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
        ),
      );

      expect(closed, isTrue);
    });

    testClient('invokes onClose on clicking outside the menu', (tester) async {
      var closed = false;

      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () => closed = true,
          items: [
            ContextMenuItem(label: 'Action', onPressed: () {}),
          ],
        ),
      );

      await pumpEventQueue();

      // Click on the document outside the menu
      web.document.body?.dispatchEvent(
        web.MouseEvent(
          'mousedown',
          web.MouseEventInit(bubbles: true, cancelable: true),
        ),
      );

      expect(closed, isTrue);
    });

    testClient('exception safety: invokes onClose even if onPressed throws synchronously', (tester) async {
      var closed = false;
      Object? caughtError;

      await runZonedGuarded(
        () async {
          tester.pumpComponent(
            ContextMenu(
              x: 10,
              y: 10,
              onClose: () => closed = true,
              items: [
                ContextMenuItem(
                  label: 'Throws Exception',
                  onPressed: () => throw StateError('Deliberate test exception'),
                ),
              ],
            ),
          );

          await pumpEventQueue();

          final button = web.document.querySelector('.context-menu-item') as web.HTMLButtonElement?;
          button?.click();
          await pumpEventQueue();
        },
        (error, stack) {
          caughtError = error;
        },
      );

      expect(caughtError, isA<StateError>());
      expect(closed, isTrue);
    });
  });

  group('ContextMenu Keyboard Navigation & WAI-ARIA', () {
    testClient('focuses first enabled item on open and skips disabled items', (tester) async {
      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () {},
          items: [
            const ContextMenuItem(label: 'Disabled Item', disabled: true, onPressed: _noop),
            ContextMenuItem(label: 'First Enabled Item', onPressed: () {}),
            ContextMenuItem(label: 'Second Enabled Item', onPressed: () {}),
          ],
        ),
      );

      await pumpEventQueue();

      final buttons = web.document.querySelectorAll('.context-menu-item');
      final firstEnabledButton = buttons.item(1) as web.HTMLButtonElement;

      expect(web.document.activeElement, equals(firstEnabledButton));
    });

    testClient('navigates with ArrowDown, ArrowUp, Home, and End keys, skipping disabled items', (tester) async {
      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () {},
          items: [
            ContextMenuItem(label: 'Item 1', onPressed: () {}),
            const ContextMenuItem(label: 'Item 2 (Disabled)', disabled: true, onPressed: _noop),
            ContextMenuItem(label: 'Item 3', onPressed: () {}),
            ContextMenuItem(label: 'Item 4', onPressed: () {}),
          ],
        ),
      );

      await pumpEventQueue();

      final buttons = web.document.querySelectorAll('.context-menu-item');
      final item1 = buttons.item(0) as web.HTMLButtonElement;
      final item3 = buttons.item(2) as web.HTMLButtonElement;
      final item4 = buttons.item(3) as web.HTMLButtonElement;

      // Initially, Item 1 is focused
      expect(web.document.activeElement, equals(item1));

      // ArrowDown skips Item 2 (disabled) and focuses Item 3
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item3));

      // ArrowDown moves to Item 4
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item4));

      // ArrowDown wraps around to Item 1
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item1));

      // ArrowUp wraps around to Item 4
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowUp', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item4));

      // ArrowUp moves to Item 3
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowUp', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item3));

      // Home key moves to first enabled item (Item 1)
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Home', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item1));

      // End key moves to last enabled item (Item 4)
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'End', bubbles: true, cancelable: true)),
      );
      expect(web.document.activeElement, equals(item4));
    });

    testClient('activates focused item on Enter and Space keys', (tester) async {
      var item1Triggered = false;
      var item2Triggered = false;
      var closedCount = 0;

      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () => closedCount++,
          items: [
            ContextMenuItem(label: 'Item 1', onPressed: () => item1Triggered = true),
            ContextMenuItem(label: 'Item 2', onPressed: () => item2Triggered = true),
          ],
        ),
      );

      await pumpEventQueue();

      // Item 1 is focused by default -> trigger with Enter
      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true)),
      );
      await pumpEventQueue();
      expect(item1Triggered, isTrue);
      expect(closedCount, 1);

      // Move focus to Item 2 -> trigger with Space
      final buttons = web.document.querySelectorAll('.context-menu-item');
      final item2 = buttons.item(1) as web.HTMLButtonElement;
      item2.focus();

      web.document.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(key: ' ', bubbles: true, cancelable: true)),
      );
      await pumpEventQueue();
      expect(item2Triggered, isTrue);
      expect(closedCount, 2);
    });

    testClient('handles keyboard events gracefully when all items are disabled or dividers', (tester) async {
      tester.pumpComponent(
        ContextMenu(
          x: 10,
          y: 10,
          onClose: () {},
          items: const [
            ContextMenuDivider(),
            ContextMenuItem(label: 'Disabled 1', disabled: true, onPressed: _noop),
            ContextMenuDivider(),
            ContextMenuItem(label: 'Disabled 2', disabled: true, onPressed: _noop),
          ],
        ),
      );

      await pumpEventQueue();

      // Dispatching keys should not throw or crash
      for (final key in ['ArrowDown', 'ArrowUp', 'Home', 'End', 'Enter', ' ']) {
        web.document.dispatchEvent(
          web.KeyboardEvent('keydown', web.KeyboardEventInit(key: key, bubbles: true, cancelable: true)),
        );
      }
    });

    testClient('retains opacity and adjusted position across component updates', (tester) async {
      final itemsNotifier = ValueNotifier<List<ContextMenuEntry>>([
        ContextMenuItem(label: 'Item A', onPressed: () {}),
      ]);

      tester.pumpComponent(
        ListenableBuilder(
          listenable: itemsNotifier,
          builder: (context) => ContextMenu(
            x: 20,
            y: 30,
            onClose: () {},
            items: itemsNotifier.value,
          ),
        ),
      );

      await pumpEventQueue();

      final menu = web.document.querySelector('.context-menu') as web.HTMLElement?;
      expect(menu, isNotNull);
      expect(menu?.style.opacity, '1');
      expect(menu?.style.left, contains('px'));
      expect(menu?.style.top, contains('px'));

      // Update items without unmounting
      itemsNotifier.value = [
        ContextMenuItem(label: 'Item A Updated', onPressed: () {}),
      ];
      await pumpEventQueue();

      // Verify opacity does not revert to 0 on re-render
      expect(menu?.style.opacity, '1');
    });
  });

  group('EditorTabBar Context Menu', () {
    testClient('triggers context menu on tab right click', (tester) async {
      final contextMenu = ContextMenuController();
      final tab1 = _FakeEditorTab('lib/main.dart');
      final tab2 = _FakeEditorTab('lib/helper.dart');

      tester.pumpComponent(
        EditorTabBar(
          openTabs: [tab1, tab2],
          activeFile: 'lib/main.dart',
          onSwitchFile: (_) {},
          onCloseFile: (_, {discardChanges = false}) => true,
          contextMenu: contextMenu,
        ),
      );

      final tabs = web.document.querySelectorAll('.editor-tab');
      expect(tabs.length, 2);

      final firstTab = tabs.item(0) as web.HTMLElement;
      firstTab.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(clientX: 150, clientY: 250, bubbles: true, cancelable: true),
        ),
      );

      expect(contextMenu.isOpen, isTrue);
      expect(contextMenu.x, 150);
      expect(contextMenu.y, 250);
      expect(contextMenu.items.any((item) => item is ContextMenuItem && item.label == 'Close'), isTrue);
      expect(contextMenu.items.any((item) => item is ContextMenuItem && item.label == 'Close others'), isTrue);
      expect(contextMenu.items.any((item) => item is ContextMenuItem && item.label == 'Copy path'), isTrue);
    });
  });

  group('ConsolePanel Context Menu', () {
    testClient('keeps the native context menu when no controller is provided', (tester) async {
      tester.pumpComponent(
        const ConsolePanel(logs: []),
      );

      final panel = web.document.querySelector('.console-panel') as web.HTMLElement;
      final event = web.MouseEvent(
        'contextmenu',
        web.MouseEventInit(bubbles: true, cancelable: true),
      );
      panel.dispatchEvent(event);

      expect(event.defaultPrevented, isFalse);
    });

    testClient('triggers context menu on console right click', (tester) async {
      final contextMenu = ContextMenuController();
      var cleared = false;

      tester.pumpComponent(
        ConsolePanel(
          logs: [
            const ConsoleEntry(message: 'Hello World', level: Level.INFO),
          ],
          onClear: () => cleared = true,
          contextMenu: contextMenu,
        ),
      );

      final panel = web.document.querySelector('.console-panel') as web.HTMLElement;
      panel.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(clientX: 200, clientY: 300, bubbles: true, cancelable: true),
        ),
      );

      expect(contextMenu.isOpen, isTrue);
      expect(contextMenu.items.length, 2);

      final clearItem = contextMenu.items.first as ContextMenuItem;
      expect(clearItem.label, 'Clear console');
      clearItem.onPressed();
      expect(cleared, isTrue);
    });
  });

  group('ContextMenu Dynamic Mount Lifecycle', () {
    testClient('can be shown and hidden without replacing the component', (tester) async {
      final open = ValueNotifier(false);

      tester.pumpComponent(
        ListenableBuilder(
          listenable: open,
          builder: (context) => ContextMenu(
            key: const ValueKey('context-menu-host'),
            x: 100,
            y: 100,
            items: [ContextMenuItem(label: 'Item', onPressed: () {})],
            isOpen: open.value,
            onClose: () {},
          ),
        ),
      );
      await pumpEventQueue();

      final menu = web.document.querySelector('.context-menu') as web.HTMLElement;
      expect(menu.style.display, 'none');

      open.value = true;
      await pumpEventQueue();
      expect(web.document.querySelector('.context-menu'), same(menu));
      expect(menu.style.display, 'flex');

      open.value = false;
      await pumpEventQueue();
      expect(web.document.querySelector('.context-menu'), same(menu));
      expect(menu.style.display, 'none');
    });

    testClient('mounts and unmounts cleanly without DOM fragment detachment errors', (tester) async {
      final controller = ContextMenuController();

      tester.pumpComponent(
        div([
          ListenableBuilder(
            listenable: controller,
            builder: (context) => controller.isOpen
                ? ContextMenu(
                    x: controller.x,
                    y: controller.y,
                    items: controller.items,
                    onClose: controller.hide,
                  )
                : const Component.fragment([]),
          ),
        ]),
      );

      expect(web.document.querySelector('.context-menu'), isNull);

      // Open menu
      controller.show(100, 100, [
        ContextMenuItem(label: 'Item A', onPressed: () {}),
      ]);
      await pumpEventQueue();
      expect(web.document.querySelector('.context-menu'), isNotNull);

      // Close menu
      controller.hide();
      await pumpEventQueue();
      expect(web.document.querySelector('.context-menu'), isNull);

      // Re-open menu
      controller.show(150, 150, [
        ContextMenuItem(label: 'Item B', onPressed: () {}),
      ]);
      await pumpEventQueue();
      expect(web.document.querySelector('.context-menu'), isNotNull);

      // Dismiss by Escape
      web.document.dispatchEvent(
        web.KeyboardEvent(
          'keydown',
          web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
        ),
      );
      await pumpEventQueue();
      expect(web.document.querySelector('.context-menu'), isNull);
    });
  });
}

void _noop() {}

class _FakeEditorTab extends EditorTab<Component> {
  _FakeEditorTab(super.path);

  @override
  Component build() => const Component.fragment([]);

  @override
  void discardUnsavedChanges() {}

  @override
  bool get hasUnsavedChanges => false;

  @override
  bool get keepAlive => false;

  @override
  Stream<void> get onUpdate => const Stream.empty();

  @override
  Future<void> save() async {}
}
