// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// Registered shortcuts which are intentionally not shown in the dialog.
///
/// Every entry needs a reason so adding a keyboard shortcut requires an
/// explicit decision to display it or keep it undiscoverable.
const _undocumentedShortcutGroups = <String, List<String>>{
  'CodeMirror completion and panel controls, which are contextual rather than global commands.': [
    'Alt-`',
    'Alt-i',
    'Escape',
    'ArrowDown',
    'ArrowUp',
    'PageDown',
    'PageUp',
    'Enter',
  ],
  'DartPad intercepts this CodeMirror diagnostics-panel shortcut without exposing a command.': [
    'Mod-Shift-m',
    'Mod-Shift-M',
  ],
  'Built-in CodeMirror editing, navigation, selection, and history commands.': [
    'Backspace',
    'Alt-ArrowLeft',
    'Ctrl-ArrowLeft',
    'Shift-Alt-ArrowLeft',
    'Alt-ArrowRight',
    'Ctrl-ArrowRight',
    'Shift-Alt-ArrowRight',
    'Mod-Alt-ArrowUp',
    'Mod-Alt-ArrowDown',
    'Alt-l',
    'Ctrl-l',
    'Mod-i',
    'Mod-[',
    'Mod-]',
    'Mod-Alt-\\',
    'Ctrl-m',
    'Shift-Alt-m',
    'ArrowLeft',
    'Shift-ArrowLeft',
    'Mod-ArrowLeft',
    'Shift-Mod-ArrowLeft',
    'Cmd-ArrowLeft',
    'ArrowRight',
    'Shift-ArrowRight',
    'Mod-ArrowRight',
    'Shift-Mod-ArrowRight',
    'Cmd-ArrowRight',
    'Shift-ArrowUp',
    'Cmd-ArrowUp',
    'Ctrl-ArrowUp',
    'Shift-ArrowDown',
    'Cmd-ArrowDown',
    'Ctrl-ArrowDown',
    'Shift-PageUp',
    'Shift-PageDown',
    'Home',
    'Shift-Home',
    'Mod-Home',
    'Shift-Mod-Home',
    'End',
    'Shift-End',
    'Mod-End',
    'Shift-Mod-End',
    'Shift-Enter',
    'Mod-a',
    'Shift-Backspace',
    'Delete',
    'Mod-Backspace',
    'Alt-Backspace',
    'Mod-Delete',
    'Alt-Delete',
    'Ctrl-b',
    'Ctrl-f',
    'Ctrl-p',
    'Ctrl-n',
    'Ctrl-a',
    'Ctrl-e',
    'Ctrl-d',
    'Ctrl-h',
    'Ctrl-k',
    'Ctrl-Alt-h',
    'Ctrl-o',
    'Ctrl-t',
    'Ctrl-v',
    'Shift-Mod-g',
    'Mod-z',
    'Mod-y',
    'Mod-Shift-z',
    'Ctrl-Shift-z',
    'Mod-u',
    'Alt-u',
    'Mod-Shift-u',
    'Cmd-Alt-[',
    'Cmd-Alt-]',
  ],
  'DartPad save command, which is intentionally not shown in the shortcuts dialog.': ['Mod-s'],
  'Alternative browser and keyboard-layout bindings for documented comment commands.': [
    'Mod-Shift-7',
    'Mod-Shift-/',
    'Mod-Shift-Digit7',
    'Shift-Alt-Ï',
  ],
};

final undocumentedShortcutReasons = <String, String>{
  for (final group in _undocumentedShortcutGroups.entries)
    for (final key in group.value) key: group.key,
};

final class _TestLanguageServerClient implements LanguageServerClient {
  @override
  JSObject createCodeMirrorExtension(String file) => [
    cm.keymapOf(cm.formatKeymap),
    cm.keymapOf(cm.renameKeymap),
    cm.keymapOf(cm.jumpToDefinitionKeymap),
    cm.keymapOf(cm.findReferencesKeymap),
  ].toJS;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  test('every CodeMirror shortcut is documented or explicitly undiscoverable', () {
    final parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);
    final editor = CodeMirrorEditor(
      parent,
      file: 'main.dart',
      initialDoc: 'void main() {}',
      onSave: () {},
      onCodeActionRequested: () {},
      languageServerClient: _TestLanguageServerClient(),
    );
    addTearDown(() {
      editor.destroy();
      parent.remove();
    });

    final registeredKeys = cm.getRegisteredKeys(editor.view.state).toDart.map((key) => key.toDart).toSet();
    final documentedKeys = shortcutDefinitions.expand((shortcut) => shortcut.codemirrorKeys).toSet();

    for (final shortcut in shortcutDefinitions) {
      final hasKey = shortcut.codemirrorKeys.any(registeredKeys.contains);
      expect(
        hasKey,
        isTrue,
        reason:
            '"${shortcut.label}" expects one of ${shortcut.codemirrorKeys} '
            'to be registered in CodeMirror, but none were found. '
            'Registered keys: $registeredKeys',
      );
    }

    final undocumentedKeys = registeredKeys
        .difference(documentedKeys)
        .difference(undocumentedShortcutReasons.keys.toSet());
    expect(
      undocumentedKeys,
      isEmpty,
      reason:
          'The following registered keys are neither documented nor allowlisted: '
          '$undocumentedKeys. Add them to shortcutDefinitions or '
          'undocumentedShortcutReasons with a reason.',
    );

    final staleAllowlistEntries = undocumentedShortcutReasons.keys.toSet().difference(registeredKeys);
    expect(
      staleAllowlistEntries,
      isEmpty,
      reason: 'The allowlist contains keys which are no longer registered: $staleAllowlistEntries',
    );
  });
}
