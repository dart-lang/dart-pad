// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/src/lsp/diagnostic_uri_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('pathFromDiagnosticUri', () {
    test('returns a decoded workspace-relative path', () {
      expect(
        pathFromDiagnosticUri(
          'file:///workspace/project/lib/my%20file.dart',
          workspaceFolder: Uri.parse('file:///workspace/project/'),
        ),
        'lib/my file.dart',
      );
    });

    test('treats a workspace URI without a trailing slash as a directory', () {
      expect(
        pathFromDiagnosticUri(
          'file:///workspace/project/lib/main.dart',
          workspaceFolder: Uri.parse('file:///workspace/project'),
        ),
        'lib/main.dart',
      );
    });

    test('does not match sibling paths that only share a prefix', () {
      expect(
        pathFromDiagnosticUri(
          'file:///workspace/project-other/lib/main.dart',
          workspaceFolder: Uri.parse('file:///workspace/project'),
        ),
        'main.dart',
      );
    });

    test('does not relativize URIs from a different location', () {
      for (final uri in [
        'https://example.com/workspace/project/lib/main.dart',
        'file://remote/workspace/project/lib/main.dart',
      ]) {
        expect(
          pathFromDiagnosticUri(
            uri,
            workspaceFolder: Uri.parse('file:///workspace/project/'),
          ),
          'main.dart',
          reason: 'uri: $uri',
        );
      }
    });

    test('falls back to the decoded last segment outside the workspace', () {
      for (final uri in [
        'file:///other/location/file.dart',
        'file:///some/deep/path/my%20file.dart',
      ]) {
        expect(
          pathFromDiagnosticUri(
            uri,
            workspaceFolder: Uri.parse('file:///workspace/project/'),
          ),
          uri.contains('%20') ? 'my file.dart' : 'file.dart',
        );
      }
    });
  });
}
