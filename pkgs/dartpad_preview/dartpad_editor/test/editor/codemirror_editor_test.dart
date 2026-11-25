// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

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
      filePath: 'lib/main.dart',
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

  test('detaching and reattaching LSP retains text, selection and undo history', () async {
    final parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);
    final client = LanguageServerClient(
      languageServer: null,
      rootWorkspaceUri: Uri.parse('file:///workspace/'),
      editorRootUri: Uri.parse('file:///workspace/'),
      workspaceChangeEvents: const Stream.empty(),
      languageServerMessages: const Stream.empty(),
      sendToLanguageServer: (_) {},
    );
    final editor = CodeMirrorEditor(parent, filePath: 'main.dart', initialDoc: 'void main() {}');
    addTearDown(() async {
      editor.destroy();
      parent.remove();
      await client.dispose();
    });
    editor.attachLanguageServerClient(client);
    editor.text = '// edited\nvoid main() {}';
    editor.view.dispatch(cm.TransactionSpec(selection: cm.EditorSelection.single(5)));
    editor.attachLanguageServerClient(null);
    editor.attachLanguageServerClient(client);
    expect(editor.text, '// edited\nvoid main() {}');
    expect(editor.view.state.selection.main.head, 5);

    final isMac = web.window.navigator.platform.toLowerCase().contains('mac');
    editor.view.contentDOM.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'z', code: 'KeyZ', ctrlKey: !isMac, metaKey: isMac, bubbles: true, cancelable: true),
      ),
    );
    expect(editor.text, 'void main() {}');
  });

  test('renaming a Dart file clears its editor diagnostics', () async {
    final parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);
    final messages = StreamController<Object?>();
    final outgoing = <Object?>[];
    final outgoingEvents = StreamController<Map<String, Object?>>.broadcast(sync: true);
    final client = LanguageServerClient(
      languageServer: null,
      rootWorkspaceUri: Uri.parse('file:///workspace/'),
      editorRootUri: Uri.parse('file:///workspace/'),
      workspaceChangeEvents: const Stream.empty(),
      languageServerMessages: messages.stream,
      sendToLanguageServer: (message) {
        outgoing.add(message);
        outgoingEvents.add(message as Map<String, Object?>);
      },
    );
    final editor = CodeMirrorEditor(
      parent,
      filePath: 'main.dart',
      initialDoc: 'void main() {}',
      languageServerClient: client,
    );
    addTearDown(() async {
      editor.destroy();
      parent.remove();
      await client.dispose();
      await messages.close();
      await outgoingEvents.close();
    });

    final initialize = outgoing.cast<Map<String, Object?>>().firstWhere((message) => message['method'] == 'initialize');
    final opened = outgoingEvents.stream.firstWhere((message) => message['method'] == 'textDocument/didOpen');
    messages.add({
      'jsonrpc': '2.0',
      'id': initialize['id'],
      'result': {'capabilities': <String, Object?>{}},
    });
    await opened;
    final firstDiagnostics = client.diagnosticsStream.first;
    messages.add({
      'jsonrpc': '2.0',
      'method': 'textDocument/publishDiagnostics',
      'params': {
        'uri': 'file:///workspace/main.dart',
        'diagnostics': [
          {
            'range': {
              'start': {'line': 0, 'character': 0},
              'end': {'line': 0, 'character': 4},
            },
            'severity': 1,
            'message': 'problem',
          },
        ],
      },
    });
    await firstDiagnostics;
    expect(parent.querySelector('.cm-lintRange-error'), isNotNull);

    editor.applyRename('main.md');
    expect(parent.querySelector('.cm-lintRange-error'), isNull);

    final reopened = outgoingEvents.stream.firstWhere((message) => message['method'] == 'textDocument/didOpen');
    editor.applyRename('main.dart');
    await reopened;
    expect(parent.querySelector('.cm-lintRange-error'), isNull);
    final newDiagnostics = client.diagnosticsStream.first;
    messages.add({
      'jsonrpc': '2.0',
      'method': 'textDocument/publishDiagnostics',
      'params': {
        'uri': 'file:///workspace/main.dart',
        'diagnostics': [
          {
            'range': {
              'start': {'line': 0, 'character': 5},
              'end': {'line': 0, 'character': 9},
            },
            'severity': 1,
            'message': 'new problem',
          },
        ],
      },
    });
    await newDiagnostics;
    expect(parent.querySelector('.cm-lintRange-error')?.textContent, 'main');
    final clearedDiagnostics = client.diagnosticsStream.first;
    messages.add({
      'jsonrpc': '2.0',
      'method': 'textDocument/publishDiagnostics',
      'params': {'uri': 'file:///workspace/main.dart', 'diagnostics': <Object?>[]},
    });
    await clearedDiagnostics;
    expect(parent.querySelector('.cm-lintRange-error'), isNull);
  });

  test('triggers onRun callback on Mod-Enter key event', () async {
    final parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);

    var runTriggered = false;
    final editor = CodeMirrorEditor(
      parent,
      filePath: 'lib/main.dart',
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

    editor.view.contentDOM.dispatchEvent(event);
    await pumpEventQueue();

    expect(runTriggered, isTrue);
  });

  test('triggers onBlur callback once when editor loses focus', () async {
    final parent = web.HTMLDivElement();
    final outsideButton = web.HTMLButtonElement();
    web.document.body!.appendChild(parent);
    web.document.body!.appendChild(outsideButton);

    var blurCount = 0;
    final editor = CodeMirrorEditor(
      parent,
      filePath: 'lib/main.dart',
      initialDoc: 'void main() {}',
      onBlur: () {
        blurCount++;
      },
    );

    addTearDown(() {
      editor.destroy();
      parent.remove();
      outsideButton.remove();
    });

    editor.focus();
    await pumpEventQueue();
    outsideButton.focus();
    await pumpEventQueue();

    expect(blurCount, 1);
  });
}
