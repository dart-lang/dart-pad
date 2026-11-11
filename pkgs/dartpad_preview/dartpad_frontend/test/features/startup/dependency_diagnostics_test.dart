// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/startup/strip_unavailable_dependencies.dart';
import 'package:test/test.dart';

void main() {
  group('dependencyDiagnosticsInWorkspace', () {
    late MemoryWorkspaceResourceApi workspace;

    setUp(() {
      workspace = MemoryWorkspaceResourceApi();
    });

    test('reports an unavailable dependency at its name position', () async {
      await workspace.writeFileFromText('pubspec.yaml', 'name: app\ndependencies:\n  missing:\n    path: ../missing\n');

      final diagnostics = await dependencyDiagnosticsInWorkspace(workspace);

      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.fileName, 'pubspec.yaml');
      expect(diagnostics.single.diagnostic.line, 2);
      expect(diagnostics.single.diagnostic.character, 2);
      expect(diagnostics.single.diagnostic.message, contains('"missing"'));
    });

    test('clears the entry once the target package exists', () async {
      await workspace.writeFileFromText(
        'pubspec.yaml',
        'name: app\ndependencies:\n  local:\n    path: packages/local\n',
      );
      expect(await dependencyDiagnosticsInWorkspace(workspace), hasLength(1));

      await workspace.writeFileFromText('packages/local/pubspec.yaml', 'name: local\n');

      expect(await dependencyDiagnosticsInWorkspace(workspace), isEmpty);
    });

    test('reports again when the target package is removed', () async {
      await workspace.writeFileFromText(
        'pubspec.yaml',
        'name: app\ndependencies:\n  local:\n    path: packages/local\n',
      );
      await workspace.writeFileFromText('packages/local/pubspec.yaml', 'name: local\n');
      expect(await dependencyDiagnosticsInWorkspace(workspace), isEmpty);

      await workspace.deleteFileSystemEntity('packages/local');

      expect(await dependencyDiagnosticsInWorkspace(workspace), hasLength(1));
    });

    test('clears the entry when pubspec_overrides.yaml supplies an available path', () async {
      await workspace.writeFileFromText(
        'pubspec.yaml',
        'name: app\ndependencies:\n  local:\n    git: https://example.com/local.git\n',
      );
      expect(await dependencyDiagnosticsInWorkspace(workspace), hasLength(1));

      await workspace.writeFileFromText('packages/local/pubspec.yaml', 'name: local\n');
      await workspace.writeFileFromText(
        'pubspec_overrides.yaml',
        'dependency_overrides:\n  local:\n    path: packages/local\n',
      );

      expect(await dependencyDiagnosticsInWorkspace(workspace), isEmpty);
    });

    test('reports unavailable dev_dependencies and dependency_overrides', () async {
      await workspace.writeFileFromText(
        'pubspec.yaml',
        'name: app\ndev_dependencies:\n  missing:\n    path: ../missing\n'
            'dependency_overrides:\n  other:\n    path: ../other\n',
      );

      final diagnostics = await dependencyDiagnosticsInWorkspace(workspace);

      expect(diagnostics.map((entry) => entry.diagnostic.message), [
        contains('"missing"'),
        contains('"other"'),
      ]);
    });

    test('skips pubspec files that are not valid YAML mappings', () async {
      await workspace.writeFileFromText('pubspec.yaml', 'dependencies: [');

      expect(await dependencyDiagnosticsInWorkspace(workspace), isEmpty);
    });
  });
}
