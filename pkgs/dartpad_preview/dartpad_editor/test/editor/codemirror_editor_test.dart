// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
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

  test('registers Mod-Enter in keymap', () {
    final parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);

    final editor = CodeMirrorEditor(
      parent,
      file: 'lib/main.dart',
      initialDoc: 'void main() {}',
      onRun: () {},
    );

    addTearDown(() {
      editor.destroy();
      parent.remove();
    });

    final registeredKeys = cm.getRegisteredKeys(editor.view.state).toDart.map((k) => k.toDart).toSet();
    expect(registeredKeys.contains('Mod-Enter'), isTrue);
  });

  test('triggers onRun callback on Mod-Enter key event', () async {
    final parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);

    var runTriggered = false;
    final editor = CodeMirrorEditor(
      parent,
      file: 'lib/main.dart',
      initialDoc: 'void main() {}',
      onRun: () {
        runTriggered = true;
      },
    );

    addTearDown(() {
      editor.destroy();
      parent.remove();
    });

    final isMac =
        web.window.navigator.platform.toLowerCase().contains('mac') ||
        web.window.navigator.userAgent.toLowerCase().contains('mac');

    final event = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(
        key: 'Enter',
        code: 'Enter',
        ctrlKey: !isMac,
        metaKey: isMac,
        bubbles: true,
        cancelable: true,
      ),
    );
    (event as JSObject).setProperty('keyCode'.toJS, 13.toJS);
    (event as JSObject).setProperty('which'.toJS, 13.toJS);

    editor.view.contentDOM.dispatchEvent(event);
    await pumpEventQueue();

    expect(runTriggered, isTrue);
  });
}
