// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeWorkspacePath canonicalizes POSIX paths and the root', () {
    final cases = {
      'lib/main.dart': 'lib/main.dart',
      '.': '',
      '': '',
      'lib//src///main.dart': 'lib/src/main.dart',
      'lib/../src/main.dart': 'src/main.dart',
      'lib/./src/./main.dart': 'lib/src/main.dart',
      '/absolute/path.dart': '/absolute/path.dart',
    };

    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(normalizeWorkspacePath(input), expected, reason: 'input: $input');
    }
  });

  test('parentWorkspacePath preserves the empty workspace root', () {
    expect(parentWorkspacePath(''), '');
    expect(parentWorkspacePath('.'), '');
    expect(parentWorkspacePath('lib'), '');
    expect(parentWorkspacePath('lib/src/main.dart'), 'lib/src');
  });

  test('basenameWorkspacePath normalizes before returning the final segment', () {
    expect(basenameWorkspacePath('lib/../web/main.dart'), 'main.dart');
    expect(basenameWorkspacePath('packages/example/.'), 'example');
  });

  test('joinWorkspacePath returns a normalized workspace path', () {
    expect(joinWorkspacePath('', 'lib/main.dart'), 'lib/main.dart');
    expect(joinWorkspacePath('.', 'lib/../web/main.dart'), 'web/main.dart');
    expect(joinWorkspacePath('packages/example/.', 'lib/main.dart'), 'packages/example/lib/main.dart');
  });

  test('isWithinWorkspaceFolder includes the folder and descendants', () {
    expect(isWithinWorkspaceFolder('', ''), isTrue);
    expect(isWithinWorkspaceFolder('lib/main.dart', ''), isTrue);
    expect(isWithinWorkspaceFolder('lib', 'lib'), isTrue);
    expect(isWithinWorkspaceFolder('lib/src/main.dart', 'lib'), isTrue);
    expect(isWithinWorkspaceFolder('library/main.dart', 'lib'), isFalse);
    expect(isWithinWorkspaceFolder('lib', 'lib/src'), isFalse);
  });

  test('isWithinWorkspaceFolder rejects paths outside the workspace', () {
    expect(isWithinWorkspaceFolder('../outside.dart', ''), isFalse);
    expect(isWithinWorkspaceFolder('lib/../../outside.dart', ''), isFalse);
    expect(isWithinWorkspaceFolder('/sdk/lib/core.dart', ''), isFalse);
    expect(isWithinWorkspaceFolder('..hidden/file.dart', ''), isTrue);
    expect(isWithinWorkspaceFolder('../outside/file.dart', '../outside'), isFalse);
  });

  test('rebaseWorkspacePath rebases the folder and its descendants', () {
    expect(rebaseWorkspacePath('lib', 'lib', 'src'), 'src');
    expect(rebaseWorkspacePath('lib/nested/main.dart', 'lib', 'src'), 'src/nested/main.dart');
  });

  test('rebaseWorkspacePath leaves paths outside the source folder unchanged', () {
    expect(rebaseWorkspacePath('library/main.dart', 'lib', 'src'), 'library/main.dart');
  });
}
