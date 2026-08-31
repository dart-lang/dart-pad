// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:test/test.dart';

void main() {
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
