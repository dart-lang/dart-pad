// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/editor/components/editor_breadcrumbs.dart';
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
  });
}
