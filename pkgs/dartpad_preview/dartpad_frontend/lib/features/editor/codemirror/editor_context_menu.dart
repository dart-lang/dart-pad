// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/components/shortcut_definitions.dart';
import '../../shared/events/error_toast_event.dart';

/// Builds the context menu items for a [CodeMirrorEditor].
List<ContextMenuEntry> buildEditorContextMenu({
  required CodeMirrorEditor editor,
  required String path,
  AppEventBus? events,
}) {
  if (!path.endsWith('.dart')) {
    return [
      ContextMenuItem.fromShortcut(
        shortcut: ShortcutDefinition.cut,
        onPressed: () => handleEditorCut(editor),
      ),
      ContextMenuItem.fromShortcut(
        shortcut: ShortcutDefinition.copy,
        onPressed: () => handleEditorCopy(editor),
      ),
      ContextMenuItem.fromShortcut(
        shortcut: ShortcutDefinition.paste,
        onPressed: () {
          unawaited(
            handleEditorPaste(
              editor,
              mod: resolveDisplayKey('Mod'),
              onPasteError: (message) => events?.dispatch(ErrorToastEvent(message)),
            ),
          );
        },
      ),
    ];
  }

  return [
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.goToDefinition,
      onPressed: () => dispatchEditorKey(editor, key: 'F12', code: 'F12'),
    ),
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.findReferences,
      onPressed: () => dispatchEditorKey(editor, key: 'F12', code: 'F12', shiftKey: true),
    ),
    const ContextMenuDivider(),
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.renameSymbol,
      onPressed: () => dispatchEditorKey(editor, key: 'F2', code: 'F2'),
    ),
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.formatDocument,
      onPressed: () => unawaited(editor.format()),
    ),
    const ContextMenuDivider(),
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.cut,
      onPressed: () => handleEditorCut(editor),
    ),
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.copy,
      onPressed: () => handleEditorCopy(editor),
    ),
    ContextMenuItem.fromShortcut(
      shortcut: ShortcutDefinition.paste,
      onPressed: () {
        unawaited(
          handleEditorPaste(
            editor,
            mod: resolveDisplayKey('Mod'),
            onPasteError: (message) => events?.dispatch(ErrorToastEvent(message)),
          ),
        );
      },
    ),
  ];
}

/// Dispatches a synthetic keyboard event to CodeMirror's DOM element.
void dispatchEditorKey(
  CodeMirrorEditor editor, {
  required String key,
  required String code,
  bool ctrlKey = false,
  bool altKey = false,
  bool shiftKey = false,
  bool metaKey = false,
}) {
  editor.focus();
  final target = editor.view.contentDOM;
  final event = web.KeyboardEvent(
    'keydown',
    web.KeyboardEventInit(
      key: key,
      code: code,
      ctrlKey: ctrlKey,
      altKey: altKey,
      shiftKey: shiftKey,
      metaKey: metaKey,
      bubbles: true,
      cancelable: true,
    ),
  );
  target.dispatchEvent(event);
}

/// Copies selected text (or the active line) to clipboard.
///
/// [writeClipboard] exists to make the copy logic independently testable.
void handleEditorCopy(
  CodeMirrorEditor editor, {
  Future<void> Function(String text)? writeClipboard,
}) {
  final state = editor.view.state;
  final ranges = state.selection.ranges.toDart;
  final String text;
  final hasNonEmpty = ranges.any((r) => !r.empty);
  if (hasNonEmpty) {
    text = ranges.where((r) => !r.empty).map((r) => state.sliceDoc(r.from, r.to).toDart).join('\n');
  } else {
    final buffer = StringBuffer();
    final seenLines = <int>{};
    for (final range in ranges) {
      // Copy the entire line when there is no selection (VS Code behavior).
      final line = state.doc.lineAt(range.from);
      if (seenLines.add(line.from)) {
        buffer.writeln(state.sliceDoc(line.from, line.to).toDart);
      }
    }
    text = buffer.toString();
  }
  if (text.isNotEmpty) {
    unawaited(
      (writeClipboard ?? _writeClipboardText)(text).catchError((Object e) {
        web.console.warn('Clipboard write failed: $e'.toJS);
      }),
    );
  }
  editor.focus();
}

/// Cuts selected text (or the active line) to clipboard and removes it from the editor.
///
/// [writeClipboard] exists to make the cut logic independently testable.
void handleEditorCut(
  CodeMirrorEditor editor, {
  Future<void> Function(String text)? writeClipboard,
}) {
  final state = editor.view.state;
  final ranges = state.selection.ranges.toDart;
  final changes = <cm.ChangeSpec>[];
  final String text;
  final hasNonEmpty = ranges.any((r) => !r.empty);
  if (hasNonEmpty) {
    final pieces = <String>[];
    for (final range in ranges) {
      if (!range.empty) {
        pieces.add(state.sliceDoc(range.from, range.to).toDart);
        changes.add(cm.ChangeSpec(from: range.from, to: range.to, insert: ''.toJS));
      }
    }
    text = pieces.join('\n');
  } else {
    final buffer = StringBuffer();
    final seenLines = <int>{};
    for (final range in ranges) {
      // Cut the entire line when there is no selection (VS Code behavior).
      final line = state.doc.lineAt(range.from);
      if (!seenLines.add(line.from)) {
        continue;
      }
      final int from;
      final int to;
      if (line.to < state.doc.length) {
        // Include the newline character so the line is fully removed.
        from = line.from;
        to = line.to + 1;
      } else if (line.from > 0) {
        // On the last line, include the preceding newline character so no
        // empty ghost line remains.
        from = line.from - 1;
        to = line.to;
      } else {
        from = line.from;
        to = line.to;
      }
      buffer.writeln(state.sliceDoc(line.from, line.to).toDart);
      changes.add(cm.ChangeSpec(from: from, to: to, insert: ''.toJS));
    }
    text = buffer.toString();
  }
  if (text.isNotEmpty) {
    unawaited(
      (writeClipboard ?? _writeClipboardText)(text).catchError((Object e) {
        web.console.warn('Clipboard write failed: $e'.toJS);
      }),
    );
  }
  if (changes.isNotEmpty) {
    editor.view.dispatch(
      cm.TransactionSpec(changes: changes.toJS),
    );
  }
  editor.focus();
}

/// Pastes text from the system clipboard into the editor.
///
/// [readClipboard] exists to make the editor update independently testable.
/// The production path calls the Clipboard API immediately, while the menu
/// item's click still has a transient browser user activation.
Future<void> handleEditorPaste(
  CodeMirrorEditor editor, {
  void Function(String message)? onPasteError,
  String mod = 'Ctrl',
  Future<String> Function()? readClipboard,
}) async {
  try {
    // Invoke the privileged browser API before doing anything else so this
    // call stays inside the menu click's transient user activation.
    final pasteText = await (readClipboard ?? _readClipboardText)();
    if (pasteText.isEmpty) {
      return;
    }

    final selection = editor.view.state.selection;
    final changes = <cm.ChangeSpec>[];
    final pastedRanges = <cm.SelectionRange>[];
    var offset = 0;
    for (final range in selection.ranges.toDart) {
      changes.add(
        cm.ChangeSpec(
          from: range.from,
          to: range.to,
          insert: pasteText.toJS,
        ),
      );
      pastedRanges.add(
        cm.EditorSelection.cursor(range.from + offset + pasteText.length),
      );
      offset += pasteText.length - (range.to - range.from);
    }
    editor.view.dispatch(
      cm.TransactionSpec(
        changes: changes.toJS,
        selection: cm.EditorSelection.create(pastedRanges.toJS, selection.mainIndex),
      ),
    );
  } catch (_) {
    onPasteError?.call(
      'Paste failed. The browser may not have clipboard permission. '
      'Allow clipboard access for this site, or use $mod + V.',
    );
  } finally {
    editor.focus();
  }
}

Future<String> _readClipboardText() async => (await web.window.navigator.clipboard.readText().toDart).toDart;

Future<void> _writeClipboardText(String text) async => web.window.navigator.clipboard.writeText(text).toDart;
