import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_preview_shared/workspace/workspace_resource.dart';
import 'package:dartpad_preview_shared/workspace/workspace_watcher.dart';
import 'package:test/test.dart';

class MemoryWorkspace implements Workspace {
  final Map<String, Uint8List> files = {};
  final Set<String> folders = {''};
  final List<String> mutations = [];

  @override
  int get id => 0;

  @override
  Uri get workspaceFolder => Uri.parse('file:///workspace/');

  @override
  Stream<WorkspaceEvent> get fileSystemChanges => const Stream.empty();

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
}
