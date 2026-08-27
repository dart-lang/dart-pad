// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

/// Whether the current platform is macOS.
final _isMac = web.window.navigator.platform.toLowerCase().contains('mac');

/// Resolves platform-agnostic modifier placeholders in a display key string.
///
/// - `Mod` → `⌘` on macOS, `Ctrl` on other platforms.
String resolveDisplayKey(String key) => key.replaceAll('Mod', _isMac ? '⌘' : 'Ctrl');

/// Categories for grouping keyboard shortcuts in the shortcuts dialog.
enum ShortcutCategory {
  refactoring('Refactoring & code intelligence'),
  editing('Editing'),
  search('Search'),
  autocompleteFolding('Autocomplete & folding');

  const ShortcutCategory(this.label);

  /// The display label used as a section header in the shortcuts dialog.
  final String label;
}

/// A keyboard shortcut shown in the shortcuts dialog.
///
/// Each definition provides both the display text for the UI and the
/// corresponding CodeMirror key notation(s) used for automated testing.
class ShortcutDefinition {
  const ShortcutDefinition({
    required this.label,
    required this.displayKey,
    required this.codemirrorKeys,
    required this.category,
    this.isPrimary = true,
  });

  /// Human-readable command name, e.g. `'Quick fix'`.
  final String label;

  /// Display string shown in the dialog.
  ///
  /// May contain the placeholder `Mod` which is resolved at render time
  /// via [resolveDisplayKey] to `⌘` on macOS or `Ctrl` on other platforms.
  final String displayKey;

  /// CodeMirror key notation(s) for this shortcut.
  ///
  /// Tests verify that at least one of these keys is registered in the
  /// CodeMirror editor state. Multiple entries are used when a shortcut
  /// has platform-specific variants or aliases (e.g. `'F3'` and `'Mod-g'`
  /// for "Find next").
  final List<String> codemirrorKeys;

  /// The category this shortcut belongs to.
  final ShortcutCategory category;

  /// Whether this shortcut is shown in the collapsed (primary) view.
  ///
  /// When `false`, the shortcut is only visible after expanding the
  /// "Show more shortcuts" section.
  final bool isPrimary;
}

/// The complete list of keyboard shortcuts displayed in the shortcuts dialog.
///
/// This list is the **single source of truth** for both the dialog UI and the
/// automated test that validates shortcuts against CodeMirror's keymap.
///
/// Display keys use `Mod` as a platform-agnostic placeholder for the primary
/// modifier key. Call [resolveDisplayKey] to get the platform-specific string.
const shortcutDefinitions = <ShortcutDefinition>[
  // ── Refactoring & code intelligence ──────────────────────────────────────
  ShortcutDefinition(
    label: 'Quick fix',
    displayKey: 'Mod + .',
    codemirrorKeys: ['Mod-.'],
    category: ShortcutCategory.refactoring,
  ),
  ShortcutDefinition(
    label: 'Rename symbol',
    displayKey: 'F2',
    codemirrorKeys: ['F2'],
    category: ShortcutCategory.refactoring,
  ),
  ShortcutDefinition(
    label: 'Go to definition',
    displayKey: 'F12',
    codemirrorKeys: ['F12'],
    category: ShortcutCategory.refactoring,
  ),
  ShortcutDefinition(
    label: 'Find references',
    displayKey: 'Shift + F12',
    codemirrorKeys: ['Shift-F12'],
    category: ShortcutCategory.refactoring,
  ),
  ShortcutDefinition(
    label: 'Format Dart files',
    displayKey: 'Shift + Alt + F',
    codemirrorKeys: ['Shift-Alt-f', 'Shift-Alt-F'],
    category: ShortcutCategory.refactoring,
  ),
  ShortcutDefinition(
    label: 'Next problem',
    displayKey: 'F8',
    codemirrorKeys: ['F8'],
    category: ShortcutCategory.refactoring,
    isPrimary: false,
  ),

  // ── Editing ──────────────────────────────────────────────────────────────
  ShortcutDefinition(
    label: 'Toggle line comment',
    displayKey: 'Mod + /',
    codemirrorKeys: ['Mod-/'],
    category: ShortcutCategory.editing,
  ),
  ShortcutDefinition(
    label: 'Toggle block comment',
    displayKey: 'Shift + Alt + A',
    codemirrorKeys: ['Alt-A'],
    category: ShortcutCategory.editing,
  ),
  ShortcutDefinition(
    label: 'Move line up / down',
    displayKey: 'Alt + ↑ / ↓',
    codemirrorKeys: ['Alt-ArrowUp', 'Alt-ArrowDown'],
    category: ShortcutCategory.editing,
  ),
  ShortcutDefinition(
    label: 'Delete line',
    displayKey: 'Mod + Shift + K',
    codemirrorKeys: ['Shift-Mod-k'],
    category: ShortcutCategory.editing,
  ),
  ShortcutDefinition(
    label: 'Indent',
    displayKey: 'Tab',
    codemirrorKeys: ['Tab'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Outdent',
    displayKey: 'Shift + Tab',
    codemirrorKeys: ['Shift-Tab'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Copy line up / down',
    displayKey: 'Shift + Alt + ↑ / ↓',
    codemirrorKeys: ['Shift-Alt-ArrowUp', 'Shift-Alt-ArrowDown'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Insert blank line',
    displayKey: 'Mod + Enter',
    codemirrorKeys: ['Mod-Enter'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Jump to matching bracket',
    displayKey: r'Mod + Shift + \',
    codemirrorKeys: [r'Shift-Mod-\'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  ),

  // ── Search ───────────────────────────────────────────────────────────────
  ShortcutDefinition(
    label: 'Find',
    displayKey: 'Mod + F',
    codemirrorKeys: ['Mod-f'],
    category: ShortcutCategory.search,
  ),
  ShortcutDefinition(
    label: 'Select next occurrence',
    displayKey: 'Mod + D',
    codemirrorKeys: ['Mod-d'],
    category: ShortcutCategory.search,
  ),
  ShortcutDefinition(
    label: 'Find next',
    displayKey: 'F3 / Mod + G',
    codemirrorKeys: ['F3', 'Mod-g'],
    category: ShortcutCategory.search,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Find previous',
    displayKey: 'Shift + F3 / Mod + Shift + G',
    codemirrorKeys: ['Shift-F3', 'Mod-Shift-g'],
    category: ShortcutCategory.search,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Select all occurrences',
    displayKey: 'Mod + Shift + L',
    codemirrorKeys: ['Mod-Shift-l'],
    category: ShortcutCategory.search,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Go to line',
    displayKey: 'Mod + Alt + G',
    codemirrorKeys: ['Mod-Alt-g'],
    category: ShortcutCategory.search,
    isPrimary: false,
  ),

  // ── Autocomplete & folding ───────────────────────────────────────────────
  ShortcutDefinition(
    label: 'Trigger autocomplete',
    displayKey: 'Ctrl + Space',
    codemirrorKeys: ['Ctrl-Space'],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Fold code',
    displayKey: 'Ctrl + Shift + [',
    codemirrorKeys: ['Ctrl-Shift-['],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Unfold code',
    displayKey: 'Ctrl + Shift + ]',
    codemirrorKeys: ['Ctrl-Shift-]'],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Fold all',
    displayKey: 'Ctrl + Alt + [',
    codemirrorKeys: ['Ctrl-Alt-['],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  ),
  ShortcutDefinition(
    label: 'Unfold all',
    displayKey: 'Ctrl + Alt + ]',
    codemirrorKeys: ['Ctrl-Alt-]'],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  ),
];

/// The number of shortcut rows visible when the dialog is collapsed.
final primaryShortcutCount = shortcutDefinitions.where((s) => s.isPrimary).length;

/// The total number of shortcut rows when the dialog is expanded.
final allShortcutCount = shortcutDefinitions.length;
