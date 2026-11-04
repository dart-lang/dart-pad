// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/codemirror/codemirror_styles.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement shell;
  late CodeMirrorEditor editor;

  setUpAll(() async {
    final script = web.HTMLScriptElement()..src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    web.document.head!.appendChild(script);
    await loaded;
  });

  setUp(() {
    final styles = web.HTMLStyleElement()..textContent = codemirrorStyles.map((rule) => rule.toCss()).join('\n');
    web.document.head!.appendChild(styles);
    addTearDown(() => styles.parentNode?.removeChild(styles));
    shell = web.HTMLDivElement()
      ..className = 'editor-shell editor-shell-small'
      ..style.width = '390px'
      ..style.height = '400px';
    final container = web.HTMLDivElement()..className = 'editor-container';
    shell.appendChild(container);
    web.document.body!.appendChild(shell);
    editor = CodeMirrorEditor(
      container,
      file: 'main.dart',
      initialDoc: 'void main() {}\n// ${List.filled(500, 'x').join()}\n',
    );
  });

  tearDown(() {
    editor.destroy();
    shell.remove();
  });

  Future<void> setSmallScreen({required bool small}) async {
    shell.classList.toggle('editor-shell-small', small);
    editor.requestMeasure();
    await pumpEventQueue();
  }

  test('CodeMirror wraps long lines on mobile and restores horizontal scrolling on desktop', () async {
    final scroller = editor.view.scrollDOM;
    final source = editor.text;
    for (final small in [true, false, true]) {
      await setSmallScreen(small: small);
      // Read CodeMirror's own measured mode, in addition to checking the layout.
      expect(editor.view.getProperty<JSBoolean>('lineWrapping'.toJS).toDart, small);
      final line = shell.querySelectorAll('.cm-line').item(1)! as web.HTMLElement;
      final lineHeight = double.parse(web.window.getComputedStyle(line).lineHeight.replaceAll('px', ''));
      if (small) {
        expect(scroller.scrollWidth, lessThanOrEqualTo(scroller.clientWidth));
        expect(line.getBoundingClientRect().height, greaterThan(2 * lineHeight));
      } else {
        expect(scroller.scrollWidth, greaterThan(scroller.clientWidth));
        expect(line.getBoundingClientRect().height, closeTo(lineHeight, 1));
      }
      expect(editor.text, source);
    }
  });

  test('editor font uses 16px on mobile and restores 14px on desktop', () async {
    for (final small in [true, false, true]) {
      await setSmallScreen(small: small);
      expect(web.window.getComputedStyle(editor.view.contentDOM).fontSize, small ? '16px' : '14px');
    }
  });

  test('mobile gutters omit diagnostics while preserving line numbers and folding', () async {
    double codeOffset() {
      final line = shell.querySelector('.cm-line')!;
      final code = (web.document.createRange()..selectNodeContents(line)).getBoundingClientRect();
      return code.left - editor.view.dom.getBoundingClientRect().left;
    }

    await setSmallScreen(small: true);
    final mobileOffset = codeOffset();
    for (final small in [true, false, true]) {
      await setSmallScreen(small: small);
      final lintWidth = shell.querySelector('.cm-gutter-lint')!.getBoundingClientRect().width;
      expect(lintWidth, small ? isZero : greaterThan(0));
      for (final selector in ['.cm-lineNumbers', '.cm-foldGutter']) {
        expect(shell.querySelector(selector)!.getBoundingClientRect().width, greaterThan(0));
      }
      expect(codeOffset(), small ? closeTo(mobileOffset, 1) : greaterThan(mobileOffset));
    }
  });
}
