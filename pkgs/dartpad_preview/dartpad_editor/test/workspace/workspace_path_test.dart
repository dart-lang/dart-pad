// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceContext.relativeDisplayPath', () {
    test('displays the workspace root as a slash', () {
      expect(workspaceContext.relativeDisplayPath(path: '', projectRoot: ''), '/');
    });

    test('displays a focused archive directory as the project root', () {
      expect(
        workspaceContext.relativeDisplayPath(path: 'example', projectRoot: 'example'),
        '/',
      );
    });

    test('displays nested paths relative to the focused project root', () {
      expect(
        workspaceContext.relativeDisplayPath(
          path: 'packages/demo/example',
          projectRoot: 'packages/demo',
        ),
        'example',
      );
    });

    test('displays paths above the focused project root with parent segments', () {
      expect(
        workspaceContext.relativeDisplayPath(path: '', projectRoot: 'example'),
        '..',
      );
    });
  });
}
