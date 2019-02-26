// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:dart_pad/experimental/new_embed.dart' as new_embed;
import 'package:test/test.dart';

void main() {
  group('new_embed', () {
    setUp(() => new_embed.init());

    test('Editor tab is selected at init', () {
      final editorTab = querySelector('#editor-tab');
      expect(editorTab.attributes.keys, contains('selected'));
    });

    test('Console tab is not selected at init', () {
      final consoleTab = querySelector('#console-tab');
      expect(consoleTab.attributes.keys, isNot(contains('selected')));
    });

    test('Console tab is selected when clicked.', () {
      final consoleTab = querySelector('#console-tab');
      consoleTab.dispatchEvent(Event('click'));

      expect(consoleTab.attributes.keys, contains('selected'));
    });

    test('Editor tab is not selected when console tab is clicked', () {
      final consoleTab = querySelector('#console-tab');
      consoleTab.dispatchEvent(Event('click'));

      final editorTab = querySelector('#editor-tab');
      expect(editorTab.attributes.keys, isNot(contains('selected')));
    });

    test('Test tab is not selected at init', () {
      final testTab = querySelector('#test-tab');
      expect(testTab.attributes.keys, isNot(contains('selected')));
    });

    test('Test tab is selected when clicked.', () {
      final testTab = querySelector('#test-tab');
      testTab.dispatchEvent(Event('click'));

      expect(testTab.attributes.keys, contains('selected'));
    });

    test('Editor tab is not selected when test tab is clicked', () {
      final testTab = querySelector('#test-tab');
      testTab.dispatchEvent(Event('click'));

      final editorTab = querySelector('#editor-tab');
      expect(editorTab.attributes.keys, isNot(contains('selected')));
    });
  });
}
