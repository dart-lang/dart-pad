// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/workspace/project_path.dart';
import 'package:test/test.dart';

void main() {
  test('displays the workspace root as a slash', () {
    expect(projectRelativeDisplayPath(path: '', projectRoot: ''), '/');
  });

  test('displays a focused archive directory as the project root', () {
    expect(
      projectRelativeDisplayPath(path: 'example', projectRoot: 'example'),
      '/',
    );
  });

  test('displays nested paths relative to the focused project root', () {
    expect(
      projectRelativeDisplayPath(
        path: 'packages/demo/example',
        projectRoot: 'packages/demo',
      ),
      'example',
    );
  });

  test('displays paths above the focused project root with parent segments', () {
    expect(
      projectRelativeDisplayPath(path: '', projectRoot: 'example'),
      '..',
    );
  });
}
