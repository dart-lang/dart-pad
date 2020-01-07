// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:dart_pad/embed.dart' as embed;
import 'package:test/test.dart';

void main() {
  group('embed', () {
    setUp(() => embed.init(embed.EmbedOptions(embed.EmbedMode.flutter)));

    test('Editor tab is selected at init', () {
      final editorTab = querySelector('#editor-tab');
      expect(editorTab.attributes.keys, contains('aria-selected'));
      expect(editorTab.classes, contains('mdc-tab--active'));
    });

    test('Test tab is not selected at init', () {
      final testTab = querySelector('#test-tab');
      expect(testTab.attributes.keys, isNot(contains('aria-selected')));
      expect(testTab.classes, isNot(contains('mdc-tab--active')));
    });

    test('Test tab is selected when clicked.', () {
      final testTab = querySelector('#test-tab');
      testTab.dispatchEvent(Event('click'));

      expect(testTab.attributes.keys, contains('aria-selected'));
      expect(testTab.classes, contains('mdc-tab--active'));
    });

    test('Editor tab is not selected when test tab is clicked', () {
      final testTab = querySelector('#test-tab');
      testTab.dispatchEvent(Event('click'));

      final editorTab = querySelector('#editor-tab');
      expect(editorTab.attributes.keys, isNot(contains('aria-selected')));
      expect(editorTab.classes, isNot(contains('mdc-tab--active')));
    });
  });
  group('filterCloudUrls', () {
    test('cleans dart SDK urls', () {
      var trace =
          '(https://storage.googleapis.com/compilation_artifacts/2.2.0/dart_sdk.js:4537:11)';
      expect(embed.filterCloudUrls(trace), '([Dart SDK Source]:4537:11)');
    });
    test('cleans flutter SDK urls', () {
      var trace =
          '(https://storage.googleapis.com/compilation_artifacts/2.2.0/flutter_web.js:96550:21)';
      expect(embed.filterCloudUrls(trace), '([Flutter SDK Source]:96550:21)');
    });
  });
}
