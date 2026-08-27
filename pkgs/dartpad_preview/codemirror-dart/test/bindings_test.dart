// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'browser_test_utils.dart';

void main() {
  setUpAll(verifyCodeMirrorBundleLoaded);

  test('bundle exposes every symbol used by the Dart bindings', () {
    const expectedExports = [
      'Compartment',
      'EditorSelection',
      'EditorState',
      'EditorView',
      'basicSetup',
      'defaultHighlightStyle',
      'indentUnit',
      'indentWithTab',
      'keymap',
      'lintGutter',
      'linter',
      'LSPPlugin',
      'formatDocument',
      'dartpadTheme',
      'showPanel',
      'syntaxHighlighting',
      'toggleLineComment',
      'dartLanguage',
      'yaml',
      'markdown',
      'javascript',
      'html',
      'css',
      'json',
      'xml',
      'sass',
      'sql',
      'createLspClient',
      'gotoDefinitionOnClick',
      'diagnosticHoverToolbar',
      'forceSemanticTokensRefresh',
      'getRegisteredKeys',
      'formatKeymap',
      'renameKeymap',
      'jumpToDefinitionKeymap',
      'findReferencesKeymap',
    ];

    for (final name in expectedExports) {
      expect(
        codeMirrorNamespace.hasProperty(name.toJS),
        isTrue,
        reason: 'window._codemirror.$name is missing',
      );
    }
  });

  test('editor state and selection values round-trip through the bindings', () {
    final selection = EditorSelection.create(
      <SelectionRange>[
        EditorSelection.range(1, 4),
        EditorSelection.cursor(7),
      ].toJS,
      1,
    );
    final state = EditorState.create(
      EditorStateConfig(doc: 'one\ntwo'.toJS, selection: selection),
    );

    expect(selection.ranges.toDart, hasLength(2));
    final firstRange = selection.ranges.toDart.first;
    expect(firstRange.anchor, 1);
    expect(firstRange.head, 4);
    expect(firstRange.from, 1);
    expect(firstRange.to, 4);
    expect(firstRange.empty, isFalse);

    expect(state.doc.toJsString().toDart, 'one\ntwo');
    expect(state.doc.length, 7);
    expect(state.doc.lines, 2);
    expect(state.doc.line(2).text.toDart, 'two');
    // Multiple selections are disabled by default, so the state retains only
    // the selection identified by mainIndex.
    expect(state.selection.ranges.toDart, hasLength(1));
    expect(state.selection.main.anchor, 7);
    expect(state.selection.main.empty, isTrue);
  });

  test('EditorSelection.single creates a single selection', () {
    final selection = EditorSelection.single(2);

    expect(selection.ranges.toDart, hasLength(1));
    expect(selection.main.anchor, 2);
    expect(selection.main.head, 2);
    expect(selection.main.empty, isTrue);
  });

  test('EditorView dispatch applies ChangeSpec and TransactionSpec', () {
    final parent = web.HTMLDivElement();
    web.document.body!.append(parent);
    final view = EditorView(
      EditorViewConfig(
        parent: parent,
        state: EditorState.create(EditorStateConfig(doc: 'hello'.toJS)),
      ),
    );

    addTearDown(() {
      view.destroy();
      parent.remove();
    });

    view.dispatch(
      TransactionSpec(
        changes: ChangeSpec(from: 1, to: 4, insert: 'i'.toJS),
        selection: EditorSelection.create(
          <SelectionRange>[EditorSelection.cursor(2)].toJS,
        ),
      ),
    );

    expect(view.state.doc.toJsString().toDart, 'hio');
    expect(view.state.selection.main.anchor, 2);
    expect(view.contentDOM, isNotNull);
    expect(view.contentDOM.classList.contains('cm-content'), isTrue);
  });

  test('EditorView posAtCoords resolves coordinate position', () {
    final parent = web.HTMLDivElement();
    web.document.body!.append(parent);
    final view = EditorView(
      EditorViewConfig(
        parent: parent,
        state: EditorState.create(EditorStateConfig(doc: 'hello world'.toJS)),
      ),
    );

    addTearDown(() {
      view.destroy();
      parent.remove();
    });

    final coords = view.coordsAtPos(2);
    if (coords != null) {
      final pos = view.posAtCoords(EditorCoords(x: coords.left + 2, y: coords.top + 2));
      expect(pos, isNotNull);
    }
  });

  test('diagnostic hover renders Apply fix and reports its range', () async {
    final parent = web.HTMLDivElement()
      ..style.width = '320px'
      ..style.height = '120px';
    web.document.body!.append(parent);
    int? requestedFrom;
    int? requestedTo;

    final lintSource = ((EditorView _) {
      return [
        {
          'from': 1,
          'to': 4,
          'severity': 'warning',
          'message': 'Use const',
        },
      ].jsify();
    }).toJS;
    final state = EditorState.create(
      EditorStateConfig(
        doc: 'test'.toJS,
        extensions: [
          linter(lintSource, {'delay': 0}.jsify() as JSObject),
          diagnosticHoverToolbar(
            <ToolbarAction>[
              ToolbarAction(
                label: 'Unavailable fix'.toJS,
                isAvailable: ((EditorView _, int from, int to, JSArray<JSObject> diagnostics) {
                  return Future.value(false.toJS).toJS;
                }).toJS,
                run: ((EditorView _, int from, int to, JSArray<JSObject> diagnostics) {
                  expect(
                    true,
                    isFalse,
                    reason: 'Unavailable toolbar actions must not be rendered.',
                  );
                }).toJS,
              ),
              ToolbarAction(
                label: 'Apply fix'.toJS,
                isAvailable: ((EditorView _, int from, int to, JSArray<JSObject> diagnostics) {
                  return Future.value(true.toJS).toJS;
                }).toJS,
                run: ((EditorView _, int from, int to, JSArray<JSObject> diagnostics) {
                  expect(diagnostics.toDart, hasLength(1));
                  requestedFrom = from;
                  requestedTo = to;
                }).toJS,
              ),
            ].toJS,
          ),
        ].toJS,
      ),
    );
    final view = EditorView(EditorViewConfig(parent: parent, state: state));

    addTearDown(() {
      view.destroy();
      parent.remove();
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(view.dom.querySelector('.cm-lintRange'), isNotNull);
    final rect = view.coordsAtPos(2)!;
    final content = view.dom.querySelector('.cm-content')!;
    content.dispatchEvent(
      web.MouseEvent(
        'mousemove',
        web.MouseEventInit(
          bubbles: true,
          clientX: ((rect.left + rect.right) / 2).round(),
          clientY: ((rect.top + rect.bottom) / 2).round(),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    final buttons = web.document.querySelectorAll('.cm-diagnostic-toolbar-btn');
    expect(buttons.length, 1);
    final button = buttons.item(0) as web.HTMLButtonElement?;
    expect(button, isNotNull);
    expect(button!.textContent, 'Apply fix');
    button.click();

    expect(requestedFrom, 1);
    expect(requestedTo, 4);
  });

  test('all language factories produce CodeMirror extensions', () {
    final extensions = <JSAny>[
      dart(),
      yaml(),
      markdown(),
      javascript(),
      html(),
      css(),
      json(),
      xml(),
      sass(),
      sql(),
    ].toJS;

    final state = EditorState.create(
      EditorStateConfig(doc: 'void main() {}'.toJS, extensions: extensions),
    );

    expect(state.doc.toJsString().toDart, 'void main() {}');
  });

  test('dart language provides the comment tokens used by commands', () {
    final state = EditorState.create(
      EditorStateConfig(
        doc: 'void main() {}'.toJS,
        extensions: <JSAny>[dart()].toJS,
      ),
    );
    final languageDataAt = state.getProperty<JSFunction>(
      'languageDataAt'.toJS,
    );
    final values =
        languageDataAt.callAsFunction(
              state,
              'commentTokens'.toJS,
              0.toJS,
            )!
            as JSArray<JSObject>;
    final commentTokens = values.toDart.single;
    final block = commentTokens.getProperty<JSObject>('block'.toJS);

    expect(commentTokens.getProperty<JSString>('line'.toJS).toDart, '//');
    expect(block.getProperty<JSString>('open'.toJS).toDart, '/*');
    expect(block.getProperty<JSString>('close'.toJS).toDart, '*/');
  });
}
