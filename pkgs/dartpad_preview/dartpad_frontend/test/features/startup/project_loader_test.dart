// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:test/test.dart';

void main() {
  group('Project', () {
    test('normalizes paths and supports file operations', () {
      final originalBytes = Uint8List.fromList([1, 2, 3]);
      final project = Project([
        ProjectFile(path: './lib/src/../main.dart', bytes: originalBytes),
      ]);

      expect(project.paths, ['lib/main.dart']);
      expect(project.containsFile('lib/./main.dart'), isTrue);
      expect(project.readFile('./lib/main.dart'), orderedEquals(originalBytes));

      final addedBytes = Uint8List.fromList([4, 5, 6]);
      project.writeFile('./README.md', addedBytes);
      expect(project.readFile('README.md'), orderedEquals(addedBytes));

      final replacementBytes = Uint8List.fromList([7, 8, 9]);
      project.writeFile('lib/main.dart', replacementBytes);
      expect(project.readFile('lib/main.dart'), orderedEquals(replacementBytes));
      expect(
        project.files.map((file) => file.path),
        ['lib/main.dart', 'README.md'],
      );
    });

    test('rejects files whose normalized paths collide', () {
      expect(
        () => Project([
          ProjectFile(path: 'lib/main.dart', bytes: Uint8List(0)),
          ProjectFile(path: './lib/main.dart', bytes: Uint8List(0)),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('resolveEditorRootUri', () {
    final rootWorkspaceUri = Uri.parse('file:///workspace/pad_1/');

    test('resolves a nested package as a directory', () {
      expect(
        resolveEditorRootUri(rootWorkspaceUri, 'example'),
        Uri.parse('file:///workspace/pad_1/example/'),
      );
      expect(
        resolveEditorRootUri(rootWorkspaceUri, 'packages/demo'),
        Uri.parse('file:///workspace/pad_1/packages/demo/'),
      );
    });

    for (final entry in <String, String?>{
      'missing': null,
      'empty': '',
    }.entries) {
      test('uses the workspace root when the package root is ${entry.key}', () {
        expect(
          resolveEditorRootUri(rootWorkspaceUri, entry.value),
          rootWorkspaceUri,
        );
      });
    }
  });
}
