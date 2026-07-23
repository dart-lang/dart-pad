// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:test/test.dart';

class MemoryWorkspace implements WorkspaceApi {
  final Map<String, Uint8List> files = {};
  final Set<String> folders = {''};
  final List<String> mutations = [];
  final Map<String, String> pendingMoves = {};

  @override
  void addMoveIntention(String oldPath, String newPath) {
    pendingMoves[newPath] = oldPath;
  }

  @override
  int get id => 0;

  @override
  Uri get workspaceFolder => Uri.parse('file:///workspace/');

  @override
  Future<bool> fileExist(String uri) async => files.containsKey(uri);

  @override
  Future<bool> folderExist(String uri) async => folders.contains(uri);

  @override
  Future<Uint8List> readFileAsBytes(String uri) async => Uint8List.fromList(files[uri]!);

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) async {
    mutations.add('write:$uri');
    files[uri] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> createFolder(String uri) async {
    mutations.add('create:$uri');
    folders.add(uri);
  }

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    mutations.add('delete:$uri');
    files.removeWhere((path, _) => path == uri || path.startsWith('$uri/'));
    folders.removeWhere((path) => path == uri || path.startsWith('$uri/'));
  }

  @override
  Future<List<({String path, String type})>> listDirectory({
    required String uri,
    bool recursive = false,
    bool ignoreHidden = false,
  }) async {
    final prefix = uri.isEmpty ? '' : '$uri/';
    final entries = <({String path, String type})>[];

    for (final folder in folders) {
      if (folder.isEmpty || !folder.startsWith(prefix) || folder == uri) {
        continue;
      }
      final relative = folder.substring(prefix.length);
      if (recursive || !relative.contains('/')) {
        entries.add((path: relative, type: 'folder'));
      }
    }
    for (final file in files.keys) {
      if (!file.startsWith(prefix)) {
        continue;
      }
      final relative = file.substring(prefix.length);
      if (recursive || !relative.contains('/')) {
        entries.add((path: relative, type: 'file'));
      }
    }
    return entries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('shared target validation rejects existing files and folders', () async {
    final workspace = MemoryWorkspace()
      ..folders.addAll(['lib', 'lib/existing'])
      ..files['lib/existing.dart'] = Uint8List.fromList([1]);

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
    final workspace = MemoryWorkspace()
      ..folders.add('lib')
      ..files['lib/old.dart'] = Uint8List.fromList([0, 1, 255]);
    final file = WorkspaceFile(workspace: workspace, path: 'lib/old.dart');

    final renamed = await file.rename('new.dart');

    expect(renamed.path, 'lib/new.dart');
    expect(workspace.files['lib/new.dart'], [0, 1, 255]);
    expect(workspace.files, isNot(contains('lib/old.dart')));
    expect(workspace.pendingMoves, {'lib/new.dart': 'lib/old.dart'});
  });

  test('WorkspaceFolder.moveTo preserves a nested hierarchy and records every move', () async {
    final workspace = MemoryWorkspace()
      ..folders.addAll(['src', 'src/nested', 'archive'])
      ..files['src/a.dart'] = Uint8List.fromList([1])
      ..files['src/nested/b.dart'] = Uint8List.fromList([2]);
    final source = WorkspaceFolder(workspace: workspace, path: 'src');
    final target = WorkspaceFolder(workspace: workspace, path: 'archive');

    final moved = await source.moveTo(target);

    expect(moved.path, 'archive/src');
    expect(workspace.folders, containsAll(['archive/src', 'archive/src/nested']));
    expect(workspace.files['archive/src/a.dart'], [1]);
    expect(workspace.files['archive/src/nested/b.dart'], [2]);
    expect(workspace.folders, isNot(contains('src')));
    expect(workspace.files.keys, isNot(contains('src/a.dart')));
    expect(workspace.pendingMoves, {
      'archive/src': 'src',
      'archive/src/a.dart': 'src/a.dart',
      'archive/src/nested': 'src/nested',
      'archive/src/nested/b.dart': 'src/nested/b.dart',
    });
  });

  test('rename and move to the current path perform no mutations', () async {
    final workspace = MemoryWorkspace()
      ..folders.addAll(['lib', 'lib/src'])
      ..files['lib/main.dart'] = Uint8List.fromList([1, 2, 3]);
    final file = WorkspaceFile(workspace: workspace, path: 'lib/main.dart');
    final folder = WorkspaceFolder(workspace: workspace, path: 'lib/src');

    expect(await file.rename('main.dart'), same(file));
    expect(await file.moveTo(file.parent), same(file));
    expect(await folder.rename('src'), same(folder));
    expect(await folder.moveTo(folder.parent), same(folder));

    expect(workspace.mutations, isEmpty);
    expect(workspace.pendingMoves, isEmpty);
    expect(workspace.files['lib/main.dart'], [1, 2, 3]);
    expect(workspace.folders, contains('lib/src'));
  });

  test('file rename refuses an existing file or folder without mutating the workspace', () async {
    final workspace = MemoryWorkspace()
      ..folders.addAll(['lib', 'lib/existing'])
      ..files['lib/source.dart'] = Uint8List.fromList([1])
      ..files['lib/existing.dart'] = Uint8List.fromList([2]);
    final source = WorkspaceFile(workspace: workspace, path: 'lib/source.dart');

    await expectLater(
      source.rename('existing.dart'),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );
    await expectLater(
      source.rename('existing'),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );

    expect(workspace.mutations, isEmpty);
    expect(workspace.pendingMoves, isEmpty);
    expect(workspace.files['lib/source.dart'], [1]);
  });

  test('folder move refuses an existing target before creating or deleting anything', () async {
    final workspace = MemoryWorkspace()
      ..folders.addAll(['source', 'target', 'target/source'])
      ..files['source/a.dart'] = Uint8List.fromList([1]);
    final source = WorkspaceFolder(workspace: workspace, path: 'source');
    final target = WorkspaceFolder(workspace: workspace, path: 'target');

    await expectLater(
      source.moveTo(target),
      throwsA(isA<WorkspaceResourceConflictException>()),
    );

    expect(workspace.mutations, isEmpty);
    expect(workspace.pendingMoves, isEmpty);
    expect(workspace.files['source/a.dart'], [1]);
  });

  test('folder move rejects moving a folder into itself', () async {
    final workspace = MemoryWorkspace()..folders.addAll(['source', 'source/nested']);
    final source = WorkspaceFolder(workspace: workspace, path: 'source');
    final nested = WorkspaceFolder(workspace: workspace, path: 'source/nested');

    await expectLater(
      source.moveTo(nested),
      throwsA(isA<ArgumentError>()),
    );

    expect(workspace.mutations, isEmpty);
  });
}
