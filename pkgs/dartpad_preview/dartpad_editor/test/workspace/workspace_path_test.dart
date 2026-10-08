// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

void main() {
  test('document-relative URIs have neither a scheme nor an authority', () {
    for (final path in ['guide.md', '../guide.md', '/docs/guide.md', '#section']) {
      expect(isDocumentRelativeUri(Uri.parse(path)), isTrue, reason: path);
    }
    for (final path in ['file:///sdk/guide.md', 'https://example.com/guide.md', '//example.com/guide.md']) {
      expect(isDocumentRelativeUri(Uri.parse(path)), isFalse, reason: path);
    }
  });

  test('workspacePathFromUri decodes and normalizes resolved workspace paths', () {
    final cases = {
      '/docs/guide%20intro.md?raw=true#details': 'docs/guide intro.md',
      '/docs/../README.md': 'README.md',
      '/docs/%2e%2e/README.md': 'README.md',
      '/assets/logo%2520.png': 'assets/logo%20.png',
      '/': '',
      'docs/README.md': null,
      '//example.com/README.md': null,
      'file:///sdk/README.md': null,
      '/%2e%2e%2fREADME.md': null,
      '/docs/%2e%2e%2f%2e%2e%2fREADME.md': null,
      '/%2foutside.md': null,
    };
    for (final MapEntry(key: uri, value: expected) in cases.entries) {
      expect(workspacePathFromUri(Uri.parse(uri)), expected, reason: uri);
    }
  });

  test('relativePathWithinWorkspace accepts only URIs within the workspace', () {
    final cases = <(String, String, String?)>[
      ('file:///workspace/project/lib/main.dart', 'file:///workspace/project/', 'lib/main.dart'),
      ('file:///other/path/main.dart', 'file:///workspace/project/', null),
      ('https://host/workspace/project/main.dart', 'file:///workspace/project/', null),
      ('file:///workspace-extra/main.dart', 'file:///workspace/', null),
    ];

    for (final (uri, workspaceRoot, expected) in cases) {
      expect(
        relativePathWithinWorkspace(
          Uri.parse(uri),
          Uri.parse(workspaceRoot),
        ),
        expected,
      );
    }
  });

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
