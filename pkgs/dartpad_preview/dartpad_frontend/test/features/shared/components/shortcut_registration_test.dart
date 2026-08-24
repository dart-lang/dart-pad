// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  test('every shortcut in the dialog is registered in CodeMirror', () {
    // Build an EditorState with the same extensions used in production,
    // including LSP keymaps (loaded without a real LSP client) and the
    // custom keymaps registered by CodeMirrorEditor.
    final state = cm.EditorState.create(
      cm.EditorStateConfig(
        doc: 'void main() {}'.toJS,
        extensions: [
          cm.basicSetup,
          cm.keymapOf([cm.indentWithTab as cm.KeyBinding].toJS),
          cm.dart(),
          // LSP keymaps – just the KeyBinding arrays, no LSP client needed.
          cm.keymapOf(cm.formatKeymap),
          cm.keymapOf(cm.renameKeymap),
          cm.keymapOf(cm.jumpToDefinitionKeymap),
          cm.keymapOf(cm.findReferencesKeymap),
          // Custom keymaps registered by CodeMirrorEditor in production.
          cm.keymapOf(
            [
              cm.KeyBinding(
                key: 'Mod-.'.toJS,
                run: ((cm.EditorView v) => true.toJS).toJS,
              ),
              cm.KeyBinding(
                key: 'Mod-s'.toJS,
                run: ((cm.EditorView v) => true.toJS).toJS,
              ),
              cm.KeyBinding(
                key: 'Mod-Shift-m'.toJS,
                run: ((cm.EditorView v) => true.toJS).toJS,
              ),
              cm.KeyBinding(
                key: 'Mod-Shift-M'.toJS,
                run: ((cm.EditorView v) => true.toJS).toJS,
              ),
            ].toJS,
          ),
        ].toJS,
      ),
    );

    final registeredKeys = cm.getRegisteredKeys(state).toDart.map((k) => k.toDart).toSet();

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
  });
}
