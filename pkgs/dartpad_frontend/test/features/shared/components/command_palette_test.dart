// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/command_palette.dart';
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  List<CommandPaletteAction> createTestActions({
    void Function(CommandContext)? onPubGet,
    void Function(CommandContext)? onPubClean,
    void Function(CommandContext)? onFormat,
    void Function(CommandContext)? onRun,
  }) {
    return [
      CommandPaletteAction(
        label: 'Pub get',
        description: 'Download and resolve dependencies',
        aliases: const ['get', 'packages get'],
        onExecute: onPubGet ?? (_) {},
      ),
      CommandPaletteAction(
        label: 'Pub clean',
        description: 'Remove build and cache artifacts',
        aliases: const ['clean'],
        onExecute: onPubClean ?? (_) {},
      ),
      CommandPaletteAction.fromShortcut(
        shortcut: ShortcutDefinition.formatDocument,
        description: 'Format the currently active document',
        aliases: const ['format', 'beautify'],
        onExecute: onFormat ?? (_) {},
      ),
      CommandPaletteAction.fromShortcut(
        shortcut: ShortcutDefinition.runOrHotReload,
        description: 'Run the application or hot reload',
        aliases: const ['run', 'reload'],
        onExecute: onRun ?? (_) {},
      ),
    ];
  }

  testClient('CommandPaletteAction.fromShortcut populates properties from shortcut', (tester) {
    final action = CommandPaletteAction.fromShortcut(
      shortcut: ShortcutDefinition.runOrHotReload,
      description: 'Run the app',
      aliases: const ['run', 'reload'],
      onExecute: (_) {},
    );
    expect(action.shortcut, ShortcutDefinition.runOrHotReload);
    expect(action.label, 'Run / Hot reload');
    expect(action.description, 'Run the app');
    expect(action.aliases, ['run', 'reload']);
    expect(action.category, ShortcutCategory.execution);
    expect(action.resolvedDisplayKey, resolveDisplayKey('Mod + Enter'));
  });

  testClient('CommandPaletteAction can be constructed without shortcut', (tester) {
    final action = CommandPaletteAction(
      label: 'Pub get',
      description: 'Fetch packages',
      aliases: const ['get'],
      onExecute: (_) {},
    );
    expect(action.shortcut, isNull);
    expect(action.label, 'Pub get');
    expect(action.description, 'Fetch packages');
    expect(action.aliases, ['get']);
    expect(action.resolvedDisplayKey, isEmpty);
  });

  testClient('allCommandActions includes all expected default actions', (tester) {
    final labels = allCommandActions.map((a) => a.label).toList();
    expect(labels, [
      'Pub get',
      'Pub upgrade',
      'Pub outdated',
      'Pub downgrade',
      'Pub clean',
      'Format document',
      'Run / Hot reload',
      'Save file',
    ]);
  });

  testClient('displays all available commands directly upon opening', (tester) async {
    final actions = createTestActions();
    tester.pumpComponent(CommandPalette(actions: actions, onClose: () {}));
    await pumpEventQueue();

    final palette = web.document.querySelector('.command-palette');
    expect(palette, isNotNull);

    final items = web.document.querySelectorAll('.command-palette-item');
    expect(items.length, 4);

    final itemTitles = [
      for (var i = 0; i < items.length; i++)
        (items.item(i) as web.HTMLElement).querySelector('.command-palette-item-title')?.textContent,
    ];
    expect(itemTitles, [
      'Pub get',
      'Pub clean',
      'Format document',
      'Run / Hot reload',
    ]);

    // The first item is active by default.
    final firstItem = items.item(0) as web.HTMLElement;
    expect(firstItem.className, contains('active'));
  });

  testClient('filters commands dynamically when typing into search input', (tester) async {
    final actions = createTestActions();
    tester.pumpComponent(CommandPalette(actions: actions, onClose: () {}));
    await pumpEventQueue();

    final input = web.document.querySelector('.command-palette-input') as web.HTMLInputElement?;
    expect(input, isNotNull);

    // Search for "clean"
    input!.value = 'clean';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    var items = web.document.querySelectorAll('.command-palette-item');
    expect(items.length, 1);
    expect(items.item(0)!.textContent, contains('Pub clean'));

    // Search by alias "beautify" for format
    input.value = 'beautify';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    items = web.document.querySelectorAll('.command-palette-item');
    expect(items.length, 1);
    expect(items.item(0)!.textContent, contains('Format document'));

    // Search by alias "packages get" for pub get
    input.value = 'packages get';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    items = web.document.querySelectorAll('.command-palette-item');
    expect(items.length, 1);
    expect(items.item(0)!.textContent, contains('Pub get'));

    // Search for "reload" (matching text from "Run / Hot reload")
    input.value = 'reload';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    items = web.document.querySelectorAll('.command-palette-item');
    expect(items.length, 1);
    expect(items.item(0)!.textContent, contains('Run / Hot reload'));
  });

  testClient('displays empty message when no commands match query', (tester) async {
    final actions = createTestActions();
    tester.pumpComponent(CommandPalette(actions: actions, onClose: () {}));
    await pumpEventQueue();

    final input = web.document.querySelector('.command-palette-input') as web.HTMLInputElement?;
    input!.value = 'nonexistent command';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.command-palette-item');
    expect(items.length, 0);

    final emptyElem = web.document.querySelector('.command-palette-empty');
    expect(emptyElem, isNotNull);
    expect(emptyElem!.textContent, contains('No matching commands found'));
  });

  testClient('navigates with ArrowDown and ArrowUp', (tester) async {
    final actions = createTestActions();
    tester.pumpComponent(CommandPalette(actions: actions, onClose: () {}));
    await pumpEventQueue();

    final input = web.document.querySelector('.command-palette-input') as web.HTMLInputElement?;
    expect(input, isNotNull);

    // Initial state: item 0 is active
    var activeItem = web.document.querySelector('.command-palette-item.active');
    expect(activeItem?.textContent, contains('Pub get'));

    // Press ArrowDown -> item 1 active
    web.document.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    activeItem = web.document.querySelector('.command-palette-item.active');
    expect(activeItem?.textContent, contains('Pub clean'));

    // Press ArrowDown -> item 2 active
    web.document.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    activeItem = web.document.querySelector('.command-palette-item.active');
    expect(activeItem?.textContent, contains('Format document'));

    // Press ArrowUp -> back to item 1
    web.document.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowUp', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    activeItem = web.document.querySelector('.command-palette-item.active');
    expect(activeItem?.textContent, contains('Pub clean'));
  });

  testClient('executes selected command on Enter, passes CommandContext, and closes palette', (tester) async {
    CommandContext? capturedContext;
    var closed = false;

    final testContext = const CommandContext(projectDir: 'my_project');
    final actions = createTestActions(
      onRun: (context) => capturedContext = context,
    );
    tester.pumpComponent(
      CommandPalette(
        context: testContext,
        actions: actions,
        onClose: () => closed = true,
      ),
    );
    await pumpEventQueue();

    final input = web.document.querySelector('.command-palette-input') as web.HTMLInputElement?;
    input!.value = 'run';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    web.document.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    expect(closed, isTrue);
    expect(capturedContext, same(testContext));
  });

  testClient('executes command on item click and closes palette', (tester) async {
    var formatExecuted = false;
    var closed = false;

    final actions = createTestActions(
      onFormat: (_) => formatExecuted = true,
    );
    tester.pumpComponent(
      CommandPalette(
        actions: actions,
        onClose: () => closed = true,
      ),
    );
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.command-palette-item');
    final formatItem = items.item(2) as web.HTMLElement?; // Format Document
    formatItem?.click();
    await pumpEventQueue();

    expect(closed, isTrue);
    expect(formatExecuted, isTrue);
  });

  testClient('closes on Escape key without executing actions', (tester) async {
    var closed = false;
    var executed = false;

    final actions = createTestActions(
      onPubGet: (_) => executed = true,
    );
    tester.pumpComponent(
      CommandPalette(
        actions: actions,
        onClose: () => closed = true,
      ),
    );
    await pumpEventQueue();

    web.document.dispatchEvent(
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true)),
    );
    await pumpEventQueue();

    expect(closed, isTrue);
    expect(executed, isFalse);
  });

  testClient('closes on backdrop click', (tester) async {
    var closed = false;

    final actions = createTestActions();
    tester.pumpComponent(
      CommandPalette(
        actions: actions,
        onClose: () => closed = true,
      ),
    );
    await pumpEventQueue();

    final backdrop = web.document.querySelector('.command-palette-backdrop') as web.HTMLElement?;
    backdrop?.click();
    await pumpEventQueue();

    expect(closed, isTrue);
  });
}
