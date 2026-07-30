// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

Future<MemoryWorkspaceResourceApi> createPopulatedWorkspace({
  List<String> folders = const [],
  Map<String, List<int>> files = const {},
}) async {
  final workspace = MemoryWorkspaceResourceApi();
  for (final folder in folders) {
    if (folder.isNotEmpty) {
      await workspace.createFolder(folder);
    }
  }
  for (final file in files.entries) {
    await workspace.writeFileFromBytes(file.key, Uint8List.fromList(file.value));
  }
  return workspace;
}

void main() {
  test('shared target validation rejects existing files and folders', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['lib', 'lib/existing'],
      files: {
        'lib/existing.dart': [1],
      },
    );

    await expectLater(
      workspace.ensureTargetAvailable(
        sourcePath: 'lib/source.dart',
        targetPath: 'lib/existing.dart',
      ),
      throwsA(
        isA<WorkspaceResourceConflictException>()
            .having((error) => error.sourcePath, 'sourcePath', 'lib/source.dart')
            .having((error) => error.targetPath, 'targetPath', 'lib/existing.dart'),
      ),
    );
    await expectLater(
      workspace.ensureTargetAvailable(
        sourcePath: 'lib/source.dart',
        targetPath: 'lib/existing',
      ),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );
    await expectLater(
      workspace.ensureTargetAvailable(
        sourcePath: 'lib/source.dart',
        targetPath: 'lib/source.dart',
      ),
      completes,
    );
  });

  test('WorkspaceFile.rename preserves bytes and records the move intention', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['lib'],
      files: {
        'lib/old.dart': [0, 1, 255],
      },
    );
    final file = WorkspaceFile(workspace: workspace, path: 'lib/old.dart');

    final renamed = await file.rename('new.dart');

    expect(renamed.path, 'lib/new.dart');
    expect(await workspace.readFileAsBytes('lib/new.dart'), [0, 1, 255]);
    expect(await workspace.fileExist('lib/old.dart'), isFalse);
    expect(workspace.pendingMoves, {'lib/new.dart': 'lib/old.dart'});
  });

  test('WorkspaceFolder.moveTo preserves a nested hierarchy and records every move', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['src', 'src/nested', 'archive'],
      files: {
        'src/a.dart': [1],
        'src/nested/b.dart': [2],
      },
    );
    final source = WorkspaceFolder(workspace: workspace, path: 'src');
    final target = WorkspaceFolder(workspace: workspace, path: 'archive');

    final moved = await source.moveTo(target);

    expect(moved.path, 'archive/src');
    expect(await workspace.folderExist('archive/src'), isTrue);
    expect(await workspace.folderExist('archive/src/nested'), isTrue);
    expect(await workspace.readFileAsBytes('archive/src/a.dart'), [1]);
    expect(await workspace.readFileAsBytes('archive/src/nested/b.dart'), [2]);
    expect(await workspace.folderExist('src'), isFalse);
    expect(await workspace.fileExist('src/a.dart'), isFalse);
    expect(workspace.pendingMoves, {
      'archive/src': 'src',
      'archive/src/a.dart': 'src/a.dart',
      'archive/src/nested': 'src/nested',
      'archive/src/nested/b.dart': 'src/nested/b.dart',
    });
  });

  test('rename and move to the current path perform no mutations', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['lib', 'lib/src'],
      files: {
        'lib/main.dart': [1, 2, 3],
      },
    );
    final file = WorkspaceFile(workspace: workspace, path: 'lib/main.dart');
    final folder = WorkspaceFolder(workspace: workspace, path: 'lib/src');

    expect(await file.rename('main.dart'), same(file));
    expect(await file.moveTo(file.parent), same(file));
    expect(await folder.rename('src'), same(folder));
    expect(await folder.moveTo(folder.parent), same(folder));

    expect(workspace.pendingMoves, isEmpty);
    expect(await workspace.readFileAsBytes('lib/main.dart'), [1, 2, 3]);
    expect(await workspace.folderExist('lib/src'), isTrue);
  });

  test('file rename refuses an existing file or folder without mutating the workspace', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['lib', 'lib/existing'],
      files: {
        'lib/source.dart': [1],
        'lib/existing.dart': [2],
      },
    );
    final source = WorkspaceFile(workspace: workspace, path: 'lib/source.dart');

    await expectLater(
      source.rename('existing.dart'),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );
    await expectLater(
      source.rename('existing'),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );

    expect(workspace.pendingMoves, isEmpty);
    expect(await workspace.readFileAsBytes('lib/source.dart'), [1]);
  });

  test('folder move refuses an existing target before creating or deleting anything', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['source', 'target', 'target/source'],
      files: {
        'source/a.dart': [1],
      },
    );
    final source = WorkspaceFolder(workspace: workspace, path: 'source');
    final target = WorkspaceFolder(workspace: workspace, path: 'target');

    await expectLater(
      source.moveTo(target),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );

    expect(workspace.pendingMoves, isEmpty);
    expect(await workspace.readFileAsBytes('source/a.dart'), [1]);
  });

  test('folder move rejects moving a folder into itself', () async {
    final workspace = await createPopulatedWorkspace(
      folders: ['source', 'source/nested'],
    );
    final source = WorkspaceFolder(workspace: workspace, path: 'source');
    final nested = WorkspaceFolder(workspace: workspace, path: 'source/nested');

    await expectLater(
      source.moveTo(nested),
      throwsA(isA<ArgumentError>()),
    );
  });
}
