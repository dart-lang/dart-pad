// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/codemirror/editor_context_menu.dart';
import 'package:dartpad_frontend/features/shared/components/context_menu.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  group('EditorContextMenu', () {
    late web.HTMLElement container;
    late CodeMirrorEditor editor;

    setUp(() {
      container = web.document.createElement('div') as web.HTMLElement;
      web.document.body?.appendChild(container);
      editor = CodeMirrorEditor(
        container,
        file: 'main.dart',
        initialDoc: 'void main() {}',
      );
    });

    tearDown(() {
      editor.destroy();
      container.remove();
    });

    test('builds menu items in the exact required order', () {
      final items = buildEditorContextMenu(
        editor: editor,
        path: 'main.dart',
      );

      // Verify total items (7 actions + 2 dividers = 9 entries)
      expect(items.length, 9);

      // 1. Go to Definition
      expect(items[0], isA<ContextMenuItem>());
      final item1 = items[0] as ContextMenuItem;
      expect(item1.label, 'Go to definition');
      expect(item1.shortcut, 'F12');

      // 2. Find References
      expect(items[1], isA<ContextMenuItem>());
      final item2 = items[1] as ContextMenuItem;
      expect(item2.label, 'Find references');
      expect(item2.shortcut, 'Shift + F12');

      // Divider
      expect(items[2], isA<ContextMenuDivider>());

      // 3. Rename Symbol
      expect(items[3], isA<ContextMenuItem>());
      final item3 = items[3] as ContextMenuItem;
      expect(item3.label, 'Rename symbol');
      expect(item3.shortcut, 'F2');

      // 4. Format Document
      expect(items[4], isA<ContextMenuItem>());
      final item4 = items[4] as ContextMenuItem;
      expect(item4.label, 'Format document');
      expect(item4.shortcut, 'Shift + Alt + F');

      // Divider
      expect(items[5], isA<ContextMenuDivider>());

      // 5. Cut
      expect(items[6], isA<ContextMenuItem>());
      final item5 = items[6] as ContextMenuItem;
      expect(item5.label, 'Cut');

      // 6. Copy
      expect(items[7], isA<ContextMenuItem>());
      final item6 = items[7] as ContextMenuItem;
      expect(item6.label, 'Copy');

      // 7. Paste
      expect(items[8], isA<ContextMenuItem>());
      final item7 = items[8] as ContextMenuItem;
      expect(item7.label, 'Paste');
    });

    test('builds only edit items for non-Dart files without dividers', () {
      final items = buildEditorContextMenu(
        editor: editor,
        path: 'pubspec.yaml',
      );

      expect(items.length, 3);

      expect(items[0], isA<ContextMenuItem>());
      final item0 = items[0] as ContextMenuItem;
      expect(item0.label, 'Cut');

      expect(items[1], isA<ContextMenuItem>());
      final item1 = items[1] as ContextMenuItem;
      expect(item1.label, 'Copy');

      expect(items[2], isA<ContextMenuItem>());
      final item2 = items[2] as ContextMenuItem;
      expect(item2.label, 'Paste');

      for (final item in items) {
        expect(item, isNot(isA<ContextMenuDivider>()));
      }
    });

    test('pastes clipboard text over the current selection', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          selection: cm.EditorSelection.single(5, 9),
        ),
      );

      await handleEditorPaste(
        editor,
        readClipboard: () async => 'runApp',
      );

      expect(editor.text, 'void runApp() {}');
      expect(editor.view.state.selection.main.head, 11);
    });

    test('pastes into every selection and preserves the main selection', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'aa bb cc'.toJS),
          selection: cm.EditorSelection.create(
            [
              cm.EditorSelection.range(0, 2),
              cm.EditorSelection.range(6, 8),
            ].toJS,
            1,
          ),
        ),
      );

      await handleEditorPaste(
        editor,
        readClipboard: () async => 'X',
      );

      expect(editor.text, 'X bb X');
      final selection = editor.view.state.selection;
      expect(selection.ranges.toDart.map((range) => range.head), [1, 6]);
      expect(selection.mainIndex, 1);
      expect(selection.main.head, 6);
    });

    test('reports a clipboard read failure without editing', () async {
      String? pasteError;

      await handleEditorPaste(
        editor,
        readClipboard: () => Future<String>.error(StateError('read denied')),
        onPasteError: (message) => pasteError = message,
      );

      expect(editor.text, 'void main() {}');
      expect(pasteError, contains('browser may not have clipboard permission'));
    });

    test('copies multiple non-empty selections joined with newlines', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'first line\nsecond line\nthird line'.toJS),
          selection: cm.EditorSelection.create(
            [
              cm.EditorSelection.range(0, 5), // 'first'
              cm.EditorSelection.range(11, 17), // 'second'
              cm.EditorSelection.range(23, 28), // 'third'
            ].toJS,
          ),
        ),
      );

      String? copiedText;
      handleEditorCopy(editor, writeClipboard: (text) async => copiedText = text);

      expect(copiedText, 'first\nsecond\nthird');
    });

    test('copies single selection without trailing newline', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          selection: cm.EditorSelection.single(0, 4), // 'void'
        ),
      );

      String? copiedText;
      handleEditorCopy(editor, writeClipboard: (text) async => copiedText = text);

      expect(copiedText, 'void');
    });

    test('cuts last line without leaving a ghost empty line at end of document', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'line 1\nline 2\nline 3'.toJS),
          selection: cm.EditorSelection.single(15), // cursor on 'line 3'
        ),
      );

      String? cutText;
      handleEditorCut(editor, writeClipboard: (text) async => cutText = text);

      expect(cutText, 'line 3\n');
      expect(editor.text, 'line 1\nline 2');
    });

    test('cuts middle line cleanly', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'line 1\nline 2\nline 3'.toJS),
          selection: cm.EditorSelection.single(8), // cursor on 'line 2'
        ),
      );

      String? cutText;
      handleEditorCut(editor, writeClipboard: (text) async => cutText = text);

      expect(cutText, 'line 2\n');
      expect(editor.text, 'line 1\nline 3');
    });

    test('cuts multiple non-empty selections joined with newlines', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'aaa bbb ccc'.toJS),
          selection: cm.EditorSelection.create(
            [
              cm.EditorSelection.range(0, 3), // 'aaa'
              cm.EditorSelection.range(8, 11), // 'ccc'
            ].toJS,
          ),
        ),
      );

      String? cutText;
      handleEditorCut(editor, writeClipboard: (text) async => cutText = text);

      expect(cutText, 'aaa\nccc');
      expect(editor.text, ' bbb ');
    });

    test('cuts line with multiple cursors on the same line without duplicate changes', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'line 1\nline 2\nline 3'.toJS),
          selection: cm.EditorSelection.create(
            [
              cm.EditorSelection.cursor(7), // start of line 2
              cm.EditorSelection.cursor(10), // middle of line 2
            ].toJS,
          ),
        ),
      );

      String? cutText;
      handleEditorCut(editor, writeClipboard: (text) async => cutText = text);

      expect(cutText, 'line 2\n');
      expect(editor.text, 'line 1\nline 3');
    });

    test('copies line with multiple cursors on the same line without duplicating text', () async {
      editor.view.dispatch(
        cm.TransactionSpec(
          changes: cm.ChangeSpec(from: 0, to: editor.text.length, insert: 'line 1\nline 2\nline 3'.toJS),
          selection: cm.EditorSelection.create(
            [
              cm.EditorSelection.cursor(7), // start of line 2
              cm.EditorSelection.cursor(10), // middle of line 2
            ].toJS,
          ),
        ),
      );

      String? copiedText;
      handleEditorCopy(editor, writeClipboard: (text) async => copiedText = text);

      expect(copiedText, 'line 2\n');
    });

    test('dispatchEditorKey dispatches keydown event to contentDOM', () {
      web.Event? receivedEvent;
      final listener = ((web.Event e) {
        receivedEvent = e;
      }).toJS;

      editor.view.contentDOM.addEventListener('keydown', listener);
      addTearDown(() => editor.view.contentDOM.removeEventListener('keydown', listener));

      dispatchEditorKey(editor, key: 'F12', code: 'F12');

      expect(receivedEvent, isNotNull);
      final keyEvent = receivedEvent as web.KeyboardEvent;
      expect(keyEvent.key, 'F12');
      expect(keyEvent.code, 'F12');
      expect(keyEvent.target, equals(editor.view.contentDOM));
    });
  });
}
