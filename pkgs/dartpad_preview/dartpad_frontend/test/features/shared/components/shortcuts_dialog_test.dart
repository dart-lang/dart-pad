// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:dartpad_frontend/features/shared/components/shortcuts_dialog.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('triggers onClose on Escape keydown', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));
    await pumpEventQueue();

    final closeButton = web.document.querySelector(
      '.shortcuts-dialog-backdrop [aria-label="Close shortcuts dialog"]',
    );
    closeButton!.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();
    expect(closed, isTrue);
  });

  testClient('renders shortcuts dialog and triggers onClose on close button click', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    final dialog = web.document.querySelector('.shortcuts-dialog');
    expect(dialog, isNotNull);

    // Primary shortcut rows should match shortcut definitions.
    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, primaryShortcutCount);

    final closeBtn = dialog?.querySelector('[aria-label="Close shortcuts dialog"]') as web.HTMLButtonElement?;
    expect(closeBtn, isNotNull);
    closeBtn?.click();
    expect(closed, isTrue);
  });

  testClient('toggles between primary and extended shortcut list', (tester) async {
    tester.pumpComponent(ShortcutsDialog(onClose: () {}));

    final toggleBtn = web.document.querySelector('.shortcuts-dialog-toggle-btn') as web.HTMLButtonElement?;
    expect(toggleBtn, isNotNull);
    expect(toggleBtn?.textContent, contains('Show more shortcuts'));

    // Expand
    toggleBtn?.click();
    await pumpEventQueue();

    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, allShortcutCount);
    expect(toggleBtn?.textContent, contains('Show fewer shortcuts'));

    // Collapse
    toggleBtn?.click();
    await pumpEventQueue();

    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, primaryShortcutCount);
  });

  testClient('triggers onClose on backdrop click', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    final backdrop = web.document.querySelector('.shortcuts-dialog-backdrop') as web.HTMLElement?;
    expect(backdrop, isNotNull);
    backdrop?.click();
    expect(closed, isTrue);
  });

  testClient('renders View category with Open command palette shortcut', (tester) async {
    tester.pumpComponent(ShortcutsDialog(onClose: () {}));

    final categories = web.document.querySelectorAll('.shortcuts-dialog-category');
    final categoryTexts = [
      for (var i = 0; i < categories.length; i++) categories.item(i)?.textContent,
    ];
    expect(categoryTexts, contains('View'));

    final rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    final rowLabels = [
      for (var i = 0; i < rows.length; i++)
        (rows.item(i) as web.HTMLElement).querySelector('.shortcuts-dialog-command')?.textContent,
    ];
    expect(rowLabels, contains('Open command palette'));
  });

  testClient('renders multiple key badges with "or" separator for alternative shortcuts', (tester) async {
    tester.pumpComponent(ShortcutsDialog(onClose: () {}));

    // Expand to see all shortcuts including findNext and foldCode.
    final toggleBtn = web.document.querySelector('.shortcuts-dialog-toggle-btn') as web.HTMLButtonElement?;
    expect(toggleBtn, isNotNull);
    toggleBtn?.click();
    await pumpEventQueue();

    final rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    web.HTMLElement? findRow(String command) {
      for (var i = 0; i < rows.length; i++) {
        final row = rows.item(i) as web.HTMLElement;
        if (row.querySelector('.shortcuts-dialog-command')?.textContent == command) {
          return row;
        }
      }
      return null;
    }

    // Command with multiple key combos (Find next)
    final findNextRow = findRow('Find next');
    expect(findNextRow, isNotNull);
    final findNextKeys = findNextRow!.querySelectorAll('.shortcuts-dialog-key');
    expect(findNextKeys.length, 2);
    expect(findNextKeys.item(0)?.textContent, 'F3');
    expect(findNextKeys.item(1)?.textContent, resolveDisplayKey('Mod + G'));
    final findNextSeparator = findNextRow.querySelectorAll('.shortcuts-dialog-separator');
    expect(findNextSeparator.length, 1);
    expect(findNextSeparator.item(0)?.textContent, 'or');
    final findNextAlternatives = findNextRow.querySelectorAll('.shortcuts-dialog-alternative');
    expect(findNextAlternatives.length, 1);

    // Single combo command with platform-specific key (Fold code)
    final foldCodeRow = findRow('Fold code');
    expect(foldCodeRow, isNotNull);
    final foldCodeKeys = foldCodeRow!.querySelectorAll('.shortcuts-dialog-key');
    expect(foldCodeKeys.length, 1);
    expect(foldCodeKeys.item(0)?.textContent, ShortcutDefinition.foldCode.resolvedDisplayKey);
    final foldCodeSeparator = foldCodeRow.querySelectorAll('.shortcuts-dialog-separator');
    expect(foldCodeSeparator.length, 0);

    // Single combo command (Open command palette)
    final commandPaletteRow = findRow('Open command palette');
    expect(commandPaletteRow, isNotNull);
    final commandPaletteKeys = commandPaletteRow!.querySelectorAll('.shortcuts-dialog-key');
    expect(commandPaletteKeys.length, 1);
    expect(commandPaletteKeys.item(0)?.textContent, resolveDisplayKey('Mod + Shift + P'));
    final commandPaletteSeparator = commandPaletteRow.querySelectorAll('.shortcuts-dialog-separator');
    expect(commandPaletteSeparator.length, 0);
  });

  group('ShortcutDefinition', () {
    test('resolves display keys and joins them in displayKey', () {
      const single = ShortcutDefinition(label: 'Single', displayKey: 'Mod + S');
      expect(single.displayKeys, ['Mod + S']);
      expect(single.displayKey, 'Mod + S');
      expect(single.resolvedDisplayKeys, [resolveDisplayKey('Mod + S')]);
      expect(single.resolvedDisplayKey, resolveDisplayKey('Mod + S'));

      const multiple = ShortcutDefinition.alternatives(
        label: 'Multiple',
        displayKeys: ['F3', 'Mod + G'],
      );
      expect(multiple.displayKeys, ['F3', 'Mod + G']);
      expect(multiple.displayKey, 'F3 or Mod + G');
      expect(multiple.resolvedDisplayKeys, ['F3', resolveDisplayKey('Mod + G')]);
      expect(multiple.resolvedDisplayKey, 'F3 or ${resolveDisplayKey('Mod + G')}');

      const altShortcut = ShortcutDefinition(label: 'Format', displayKey: 'Alt + Shift + F');
      expect(altShortcut.resolvedDisplayKeys, [resolveDisplayKey('Alt + Shift + F')]);
      expect(altShortcut.resolvedDisplayKey, resolveDisplayKey('Alt + Shift + F'));
    });

    test('resolves Alt to ⌥ on macOS and Alt on other platforms', () {
      expect(resolveDisplayKey('Alt + F', onMac: true), '⌥ + F');
      expect(resolveDisplayKey('Alt + F', onMac: false), 'Alt + F');
      expect(resolveDisplayKey('Alt + Shift + ↑ / ↓', onMac: true), '⌥ + Shift + ↑ / ↓');
      expect(resolveDisplayKey('Alt + Shift + ↑ / ↓', onMac: false), 'Alt + Shift + ↑ / ↓');
      expect(resolveDisplayKey('Mod + Alt + G', onMac: true), '⌘ + ⌥ + G');
      expect(resolveDisplayKey('Mod + Alt + G', onMac: false), 'Ctrl + Alt + G');
    });

    test('resolves <mac: ... | other: ...> syntax in resolveDisplayKey', () {
      const key = '<mac: Mod + Alt + [ | other: Ctrl + Shift + [>';
      expect(resolveDisplayKey(key, onMac: true), '⌘ + ⌥ + [');
      expect(resolveDisplayKey(key, onMac: false), 'Ctrl + Shift + [');

      const foldCode = ShortcutDefinition.foldCode;
      expect(resolveDisplayKey(foldCode.displayKey, onMac: true), '⌘ + ⌥ + [');
      expect(resolveDisplayKey(foldCode.displayKey, onMac: false), 'Ctrl + Shift + [');
    });
  });
}
