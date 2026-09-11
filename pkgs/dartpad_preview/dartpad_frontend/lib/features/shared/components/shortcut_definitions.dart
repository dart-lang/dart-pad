// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

/// Whether the current platform is macOS.
final isMac =
    web.window.navigator.platform.toLowerCase().contains('mac') ||
    web.window.navigator.userAgent.toLowerCase().contains('mac');

final _platformPattern = RegExp(r'<mac:\s*(.*?)\s*\|\s*other:\s*(.*?)>');

/// Resolves platform-agnostic modifier placeholders and platform conditionals
/// in a display key string.
///
/// - `<mac: A | other: B>` → `A` on macOS, `B` on other platforms.
/// - `Mod` → `⌘` on macOS, `Ctrl` on other platforms.
/// - `Alt` → `⌥` on macOS, `Alt` on other platforms.
String resolveDisplayKey(String key, {bool? onMac}) {
  final mac = onMac ?? isMac;
  final platformResolved = key.replaceAllMapped(_platformPattern, (m) {
    return mac ? m[1]! : m[2]!;
  });
  return platformResolved
      .replaceAll('Mod', mac ? '⌘' : 'Ctrl')
      .replaceAll('Alt', mac ? '⌥' : 'Alt');
}

/// Categories for grouping keyboard shortcuts in the shortcuts dialog.
enum ShortcutCategory {
  view('View'),
  execution('Execution'),
  refactoring('Refactoring & code intelligence'),
  editing('Editing'),
  search('Search'),
  autocompleteFolding('Autocomplete & folding');

  const ShortcutCategory(this.label);

  /// The display label used as a section header in the shortcuts dialog.
  final String label;
}

/// A keyboard shortcut shown in the shortcuts dialog or context menus.
///
/// Each definition provides both the display text for the UI and the
/// corresponding CodeMirror key notation(s) used for automated testing.
///
/// Shortcuts without a [category] (such as native clipboard actions) are not
/// listed in the general shortcuts dialog and are only used for menus or
/// toolbars.
final class ShortcutDefinition {
  /// Creates a shortcut definition for a single key combination.
  const ShortcutDefinition({
    required this.label,
    required String displayKey,
    this.codemirrorKeys = const [],
    this.category,
    this.isPrimary = true,
  }) : _singleDisplayKey = displayKey,
       _alternativeDisplayKeys = null;

  /// Creates a shortcut definition with multiple alternative key combinations.
  const ShortcutDefinition.alternatives({
    required this.label,
    required List<String> displayKeys,
    this.codemirrorKeys = const [],
    this.category,
    this.isPrimary = true,
  }) : _singleDisplayKey = null,
       _alternativeDisplayKeys = displayKeys;

  /// Human-readable command name, e.g. `'Quick fix'`.
  final String label;

  final String? _singleDisplayKey;
  final List<String>? _alternativeDisplayKeys;

  /// List of display key combination(s) shown in the shortcuts dialog.
  ///
  /// Returns a single-element list if defined via [displayKey], or the alternative
  /// key combinations if defined via [displayKeys].
  /// May contain unresolved `Mod` placeholders or `<mac: ... | other: ...>` syntax.
  /// Use [resolvedDisplayKeys] for UI rendering.
  List<String> get displayKeys => _alternativeDisplayKeys ?? [_singleDisplayKey!];

  /// Display string shown in single-string contexts (e.g. context menus).
  ///
  /// When multiple display keys are defined, they are joined with `' or '`.
  /// May contain unresolved `Mod` placeholders or `<mac: ... | other: ...>` syntax.
  /// Use [resolvedDisplayKey] for UI rendering.
  String get displayKey => _singleDisplayKey ?? _alternativeDisplayKeys!.join(' or ');

  /// Resolves platform-agnostic modifier placeholders in [displayKeys] using [resolveDisplayKey].
  List<String> get resolvedDisplayKeys => displayKeys.map(resolveDisplayKey).toList();

  /// Resolves platform-agnostic modifier placeholders in [displayKey] using [resolveDisplayKey].
  String get resolvedDisplayKey => resolvedDisplayKeys.join(' or ');

  /// CodeMirror key notation(s) for this shortcut.
  ///
  /// Tests verify that at least one of these keys is registered in the
  /// CodeMirror editor state. Multiple entries are used when a shortcut
  /// has platform-specific variants or aliases (e.g. `'F3'` and `'Mod-g'`
  /// for "Find next").
  final List<String> codemirrorKeys;

  /// The category this shortcut belongs to.
  ///
  /// Shortcuts with a `null` category (such as native clipboard actions) are
  /// not listed in the general shortcuts dialog, but are used in menus and
  /// toolbars.
  final ShortcutCategory? category;

  /// Whether this shortcut is shown in the collapsed (primary) view.
  ///
  /// When `false`, the shortcut is only visible after expanding the
  /// "Show more shortcuts" section.
  final bool isPrimary;

  // ── Execution ────────────────────────────────────────────────────────────
  static const runOrHotReload = ShortcutDefinition(
    label: 'Run / Hot reload',
    displayKey: 'Mod + Enter',
    codemirrorKeys: ['Mod-Enter'],
    category: ShortcutCategory.execution,
  );

  // ── Refactoring & code intelligence ──────────────────────────────────────
  static const quickFix = ShortcutDefinition(
    label: 'Quick fix',
    displayKey: 'Mod + .',
    codemirrorKeys: ['Mod-.'],
    category: ShortcutCategory.refactoring,
  );

  static const renameSymbol = ShortcutDefinition(
    label: 'Rename symbol',
    displayKey: 'F2',
    codemirrorKeys: ['F2'],
    category: ShortcutCategory.refactoring,
  );

  static const goToDefinition = ShortcutDefinition(
    label: 'Go to definition',
    displayKey: 'F12',
    codemirrorKeys: ['F12'],
    category: ShortcutCategory.refactoring,
  );

  static const findReferences = ShortcutDefinition(
    label: 'Find references',
    displayKey: 'Shift + F12',
    codemirrorKeys: ['Shift-F12'],
    category: ShortcutCategory.refactoring,
  );

  static const formatDocument = ShortcutDefinition(
    label: 'Format document',
    displayKey: 'Alt + Shift + F',
    codemirrorKeys: ['Shift-Alt-f', 'Shift-Alt-F'],
    category: ShortcutCategory.refactoring,
  );

  static const nextProblem = ShortcutDefinition(
    label: 'Next problem',
    displayKey: 'F8',
    codemirrorKeys: ['F8'],
    category: ShortcutCategory.refactoring,
    isPrimary: false,
  );

  // ── Editing ──────────────────────────────────────────────────────────────
  static const toggleLineComment = ShortcutDefinition(
    label: 'Toggle line comment',
    displayKey: 'Mod + /',
    codemirrorKeys: ['Mod-/'],
    category: ShortcutCategory.editing,
  );

  static const toggleBlockComment = ShortcutDefinition(
    label: 'Toggle block comment',
    displayKey: 'Alt + Shift + A',
    codemirrorKeys: ['Alt-A', 'Shift-Alt-a', 'Shift-Alt-A'],
    category: ShortcutCategory.editing,
  );

  static const moveLine = ShortcutDefinition(
    label: 'Move line up / down',
    displayKey: 'Alt + ↑ / ↓',
    codemirrorKeys: ['Alt-ArrowUp', 'Alt-ArrowDown'],
    category: ShortcutCategory.editing,
  );

  static const deleteLine = ShortcutDefinition(
    label: 'Delete line',
    displayKey: 'Mod + Shift + K',
    codemirrorKeys: ['Shift-Mod-k'],
    category: ShortcutCategory.editing,
  );

  static const indent = ShortcutDefinition(
    label: 'Indent',
    displayKey: 'Tab',
    codemirrorKeys: ['Tab'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  );

  static const outdent = ShortcutDefinition(
    label: 'Outdent',
    displayKey: 'Shift + Tab',
    codemirrorKeys: ['Shift-Tab'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  );

  static const copyLine = ShortcutDefinition(
    label: 'Copy line up / down',
    displayKey: 'Alt + Shift + ↑ / ↓',
    codemirrorKeys: ['Shift-Alt-ArrowUp', 'Shift-Alt-ArrowDown'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  );

  static const jumpToMatchingBracket = ShortcutDefinition.alternatives(
    label: 'Jump to matching bracket',
    displayKeys: [r'Mod + Shift + \', 'Alt + M'],
    codemirrorKeys: [r'Shift-Mod-\', 'Alt-m'],
    category: ShortcutCategory.editing,
    isPrimary: false,
  );

  // ── Search ───────────────────────────────────────────────────────────────
  static const find = ShortcutDefinition(
    label: 'Find',
    displayKey: 'Mod + F',
    codemirrorKeys: ['Mod-f'],
    category: ShortcutCategory.search,
  );

  static const selectNextOccurrence = ShortcutDefinition(
    label: 'Select next occurrence',
    displayKey: 'Mod + D',
    codemirrorKeys: ['Mod-d'],
    category: ShortcutCategory.search,
  );

  static const findNext = ShortcutDefinition.alternatives(
    label: 'Find next',
    displayKeys: ['F3', 'Mod + G'],
    codemirrorKeys: ['F3', 'Mod-g'],
    category: ShortcutCategory.search,
    isPrimary: false,
  );

  static const findPrevious = ShortcutDefinition.alternatives(
    label: 'Find previous',
    displayKeys: ['Shift + F3', 'Mod + Shift + G'],
    codemirrorKeys: ['Shift-F3', 'Mod-Shift-g'],
    category: ShortcutCategory.search,
    isPrimary: false,
  );

  static const selectAllOccurrences = ShortcutDefinition(
    label: 'Select all occurrences',
    displayKey: 'Mod + Shift + L',
    codemirrorKeys: ['Mod-Shift-l', 'Mod-Shift-L'],
    category: ShortcutCategory.search,
    isPrimary: false,
  );

  static const goToLine = ShortcutDefinition(
    label: 'Go to line',
    displayKey: 'Mod + Alt + G',
    codemirrorKeys: ['Mod-Alt-g'],
    category: ShortcutCategory.search,
    isPrimary: false,
  );

  // ── Autocomplete & folding ───────────────────────────────────────────────
  static const triggerAutocomplete = ShortcutDefinition(
    label: 'Trigger autocomplete',
    displayKey: 'Ctrl + Space',
    codemirrorKeys: ['Ctrl-Space'],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  );

  static const foldCode = ShortcutDefinition(
    label: 'Fold code',
    displayKey: '<mac: Mod + Alt + [ | other: Ctrl + Shift + [>',
    codemirrorKeys: ['Ctrl-Shift-[', 'Cmd-Alt-['],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  );

  static const unfoldCode = ShortcutDefinition(
    label: 'Unfold code',
    displayKey: '<mac: Mod + Alt + ] | other: Ctrl + Shift + ]>',
    codemirrorKeys: ['Ctrl-Shift-]', 'Cmd-Alt-]'],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  );

  static const foldAll = ShortcutDefinition(
    label: 'Fold all',
    displayKey: 'Ctrl + Alt + [',
    codemirrorKeys: ['Ctrl-Alt-['],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  );

  static const unfoldAll = ShortcutDefinition(
    label: 'Unfold all',
    displayKey: 'Ctrl + Alt + ]',
    codemirrorKeys: ['Ctrl-Alt-]'],
    category: ShortcutCategory.autocompleteFolding,
    isPrimary: false,
  );

  // ── Native clipboard actions ─────────────────────────────────────────────
  static const cut = ShortcutDefinition(
    label: 'Cut',
    displayKey: 'Mod + X',
  );

  static const copy = ShortcutDefinition(
    label: 'Copy',
    displayKey: 'Mod + C',
  );

  static const paste = ShortcutDefinition(
    label: 'Paste',
    displayKey: 'Mod + V',
  );

  // ── File actions ─────────────────────────────────────────────────────────
  static const save = ShortcutDefinition(
    label: 'Save file',
    displayKey: 'Mod + S',
    codemirrorKeys: ['Mod-s'],
  );

  // ── Global & palette commands ───────────────────────────────────────────
  static const commandPalette = ShortcutDefinition(
    label: 'Open command palette',
    displayKey: 'Mod + Shift + P',
    category: ShortcutCategory.view,
  );
}

/// The complete list of keyboard shortcuts displayed in the shortcuts dialog.
///
/// This list is the **single source of truth** for both the dialog UI and the
/// automated test that validates shortcuts against CodeMirror's keymap.
///
/// Display keys use `Mod` and `Alt` as platform-agnostic placeholders for modifier
/// keys. Call [resolveDisplayKey] to get the platform-specific string.
const shortcutDefinitions = <ShortcutDefinition>[
  // ── View ─────────────────────────────────────────────────────────────────
  ShortcutDefinition.commandPalette,

  // ── Execution ────────────────────────────────────────────────────────────
  ShortcutDefinition.runOrHotReload,

  // ── Refactoring & code intelligence ──────────────────────────────────────
  ShortcutDefinition.quickFix,
  ShortcutDefinition.renameSymbol,
  ShortcutDefinition.goToDefinition,
  ShortcutDefinition.findReferences,
  ShortcutDefinition.formatDocument,
  ShortcutDefinition.nextProblem,

  // ── Editing ──────────────────────────────────────────────────────────────
  ShortcutDefinition.toggleLineComment,
  ShortcutDefinition.toggleBlockComment,
  ShortcutDefinition.moveLine,
  ShortcutDefinition.deleteLine,
  ShortcutDefinition.indent,
  ShortcutDefinition.outdent,
  ShortcutDefinition.copyLine,
  ShortcutDefinition.jumpToMatchingBracket,

  // ── Search ───────────────────────────────────────────────────────────────
  ShortcutDefinition.find,
  ShortcutDefinition.selectNextOccurrence,
  ShortcutDefinition.findNext,
  ShortcutDefinition.findPrevious,
  ShortcutDefinition.selectAllOccurrences,
  ShortcutDefinition.goToLine,

  // ── Autocomplete & folding ───────────────────────────────────────────────
  ShortcutDefinition.triggerAutocomplete,
  ShortcutDefinition.foldCode,
  ShortcutDefinition.unfoldCode,
  ShortcutDefinition.foldAll,
  ShortcutDefinition.unfoldAll,
];

/// The number of shortcut rows visible when the dialog is collapsed.
final primaryShortcutCount = shortcutDefinitions.where((s) => s.isPrimary).length;

/// The total number of shortcut rows when the dialog is expanded.
final allShortcutCount = shortcutDefinitions.length;
