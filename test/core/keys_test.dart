// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library dart_pad.keys_test;

import 'dart:html';

import 'package:dart_pad/core/keys.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('keys', () {
    test('printKeyEvent', () {
      expect(printKeyEvent(KeyEvent('foo', altKey: true, keyCode: KeyCode.S)),
          'alt-s');
      expect(
          printKeyEvent(KeyEvent('foo',
              shiftKey: true, altKey: true, keyCode: KeyCode.S)),
          'shift-alt-s');
      expect(printKeyEvent(KeyEvent('foo', keyCode: KeyCode.F10)), 'f10');

      if (isMac()) {
        expect(
            printKeyEvent(KeyEvent('foo', ctrlKey: true, keyCode: KeyCode.S)),
            'macctrl-s');
        expect(
            printKeyEvent(KeyEvent('foo', metaKey: true, keyCode: KeyCode.S)),
            'ctrl-s');
      } else {
        expect(
            printKeyEvent(KeyEvent('foo', ctrlKey: true, keyCode: KeyCode.S)),
            'ctrl-s');
        expect(
            printKeyEvent(KeyEvent('foo', metaKey: true, keyCode: KeyCode.S)),
            'meta-s');
      }
    });
  });
}
