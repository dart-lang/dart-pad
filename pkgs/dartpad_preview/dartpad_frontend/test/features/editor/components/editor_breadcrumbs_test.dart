// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/app_styles.dart';
import 'package:dartpad_frontend/features/editor/codemirror/codemirror_styles.dart';
import 'package:dartpad_frontend/features/editor/components/editor_breadcrumbs.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('EditorBreadcrumbs', () {
    testClient('renders single file breadcrumb', (tester) {
      tester.pumpComponent(
        const EditorBreadcrumbs(path: 'main.dart'),
      );

      final breadcrumbs = web.document.querySelector('.editor-breadcrumbs');
      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs!.getAttribute('title'), 'main.dart');

      final folders = web.document.querySelectorAll('.editor-breadcrumb-folder');
      expect(folders.length, 0);

      final files = web.document.querySelectorAll('.editor-breadcrumb-file');
      expect(files.length, 1);
      expect(files.item(0)!.textContent, contains('main.dart'));

      final separators = web.document.querySelectorAll('.editor-breadcrumb-separator');
      expect(separators.length, 0);
    });

    testClient('renders nested path with folders, file and separators', (tester) {
      tester.pumpComponent(
        const EditorBreadcrumbs(path: 'lib/src/components/button.dart'),
      );

      final breadcrumbs = web.document.querySelector('.editor-breadcrumbs');
      expect(breadcrumbs, isNotNull);

      final folders = web.document.querySelectorAll('.editor-breadcrumb-folder');
      expect(folders.length, 3);
      expect(folders.item(0)!.textContent, 'lib');
      expect(folders.item(1)!.textContent, 'src');
      expect(folders.item(2)!.textContent, 'components');

      final files = web.document.querySelectorAll('.editor-breadcrumb-file');
      expect(files.length, 1);
      expect(files.item(0)!.textContent, contains('button.dart'));

      final separators = web.document.querySelectorAll('.editor-breadcrumb-separator');
      expect(separators.length, 3);
    });

    testClient('renders nothing when path is empty', (tester) {
      tester.pumpComponent(
        const EditorBreadcrumbs(path: ''),
      );

      final breadcrumbs = web.document.querySelector('.editor-breadcrumbs');
      expect(breadcrumbs, isNull);
    });

    testClient('renders without top/bottom borders and matches code area background', (tester) {
      final previousTheme = web.document.documentElement!.getAttribute('data-theme');
      addTearDown(() {
        if (previousTheme == null) {
          web.document.documentElement!.removeAttribute('data-theme');
        } else {
          web.document.documentElement!.setAttribute('data-theme', previousTheme);
        }
      });

      tester.pumpComponent(
        div([
          Style(styles: [...appStyles, ...EditorBreadcrumbs.styles, ...codemirrorStyles]),
          const EditorBreadcrumbs(path: 'lib/main.dart'),
          const div(classes: 'editor-container', []),
        ]),
      );

      final breadcrumbs = web.document.querySelector('.editor-breadcrumbs')! as web.HTMLElement;
      final folder = web.document.querySelector('.editor-breadcrumb-folder')! as web.HTMLElement;
      final separator = web.document.querySelector('.editor-breadcrumb-separator')! as web.HTMLElement;
      final file = web.document.querySelector('.editor-breadcrumb-file')! as web.HTMLElement;
      final editorContainer = web.document.querySelector('.editor-container')! as web.HTMLElement;

      for (final (theme, expectedBackground, expectedTextColor) in [
        ('light', 'rgb(255, 255, 255)', 'rgb(208, 208, 210)'),
        ('dark', 'rgb(14, 22, 31)', 'rgb(144, 144, 144)'),
      ]) {
        web.document.documentElement!.setAttribute('data-theme', theme);
        final style = web.window.getComputedStyle(breadcrumbs);
        expect(style.borderTopWidth, '0px');
        expect(style.borderBottomWidth, '0px');
        expect(style.backgroundColor, expectedBackground);
        expect(style.backgroundColor, web.window.getComputedStyle(editorContainer).backgroundColor);
        for (final element in [breadcrumbs, folder, separator, file]) {
          expect(web.window.getComputedStyle(element).color, expectedTextColor);
        }
      }
    });
  });
}
