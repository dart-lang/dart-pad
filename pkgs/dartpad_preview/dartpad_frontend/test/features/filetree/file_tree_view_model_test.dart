// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_editor_delegate.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_models.dart';
import 'package:dartpad_frontend/features/filetree/file_tree_view_model.dart';
import 'package:jaspr/jaspr.dart';
import 'package:test/test.dart';

/// In-memory editor delegate used by the file-tree view-model tests.
final class FakeTabs extends ChangeNotifier implements FileTreeEditorDelegate {
  /// Creates a fake editor that appends operations to [operationLog].
  FakeTabs(this.operationLog);

  final List<String> operationLog;
  final List<String> openedFiles = [];
  final List<String> warnings = [];
  Error? saveError;
  List<String> dirty = [];
  String currentFile = '';

  @override
  String get activeFile => currentFile;

  @override
  List<String> get dirtyFiles => List.unmodifiable(dirty);

  @override
  void clearMessages() {}

  @override
  Future<void> openTextFile(String path) async {
    openedFiles.add(path);
    currentFile = path;
    notifyListeners();
  }

  @override
  Future<void> saveAllTabs() async {
    operationLog.add('save-all');
    final error = saveError;
    if (error != null) {
      throw error;
    }
    dirty = [];
  }

  @override
  void reportWarning(String message) {
    warnings.add(message);
  }
}

/// Language-server fake that records file-rename notifications.
final class FakeLanguageServerClient implements LanguageServerClient {
  /// Creates a fake client that appends operations to [operationLog].
  FakeLanguageServerClient(this.operationLog);

  final List<String> operationLog;
  Error? renameError;

  @override
  Future<void> willRenameFiles(String oldPath, String newPath) async {
    operationLog.add('lsp:$oldPath->$newPath');
    final error = renameError;
    if (error != null) {
      throw error;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory workspace controller used by the file-tree view-model tests.
final class FakeWorkspaceController implements WorkspaceResourceApi {
  /// Creates an empty workspace that appends operations to [operationLog].
  FakeWorkspaceController(this.operationLog) : languageServerClient = FakeLanguageServerClient(operationLog);

  final List<String> operationLog;
  final Map<String, Uint8List> files = {};
  final Set<String> folders = {''};
  final Map<String, int> fileExistChecks = {};
  int textWriteCount = 0;

  final FakeLanguageServerClient languageServerClient;

  final StreamController<WorkspaceChangeEvent> changeEventsController =
      StreamController<WorkspaceChangeEvent>.broadcast(sync: true);

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => changeEventsController.stream;

  @override
  Future<void> get changeEventsReady => Future.value();

  /// Adds a text file at [path], creating its ancestor folders as needed.
  void addTextFile(String path, String content) {
    final segments = path.split('/');
    for (var index = 1; index < segments.length; index++) {
      folders.add(segments.take(index).join('/'));
    }
    files[path] = Uint8List.fromList(content.codeUnits);
  }

  @override
  Future<bool> fileExist(String uri) async {
    fileExistChecks.update(uri, (count) => count + 1, ifAbsent: () => 1);
    return files.containsKey(uri);
  }

  @override
  Future<bool> folderExist(String uri) async => folders.contains(uri);

  @override
  Future<String> readFileAsText(String uri) async => String.fromCharCodes(files[uri]!);

  @override
  Future<Uint8List> readFileAsBytes(String uri) async => Uint8List.fromList(files[uri]!);

  @override
  Future<void> writeFileFromText(String uri, String content) async {
    textWriteCount++;
    files[uri] = Uint8List.fromList(content.codeUnits);
  }

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) async {
    files[uri] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> createFolder(String uri) async {
    folders.add(uri);
  }

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    files.removeWhere((path, _) => path == uri || path.startsWith('$uri/'));
    folders.removeWhere((path) => path == uri || path.startsWith('$uri/'));
  }

  @override
  Future<List<({String path, String type})>> listDirectory({
    required String uri,
    bool recursive = false,
  }) async {
    final prefix = uri.isEmpty ? '' : '$uri/';
    return [
      for (final folder in folders)
        if (folder.isNotEmpty &&
            folder.startsWith(prefix) &&
            (recursive || !folder.substring(prefix.length).contains('/')))
          (path: folder, type: 'folder'),
      for (final file in files.keys)
        if (file.startsWith(prefix) && (recursive || !file.substring(prefix.length).contains('/')))
          (path: file, type: 'file'),
    ];
  }

  @override
  void addMoveIntention(String oldPath, String newPath) {
    operationLog.add('move:$oldPath->$newPath');
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Exercises file-tree state transitions and workspace mutations.
void main() {
  late List<String> operationLog;
  late FakeTabs tabs;
  late FakeWorkspaceController workspace;
  late FileTreeViewModel viewModel;

  setUp(() async {
    operationLog = [];
    tabs = FakeTabs(operationLog);
    workspace = FakeWorkspaceController(operationLog)
      ..addTextFile('lib/main.dart', 'void main() {}')
      ..addTextFile('pubspec.yaml', 'name: test')
      ..addTextFile('.dart_tool/package_config.json', '{}')
      ..addTextFile('build/output.js', '');
    viewModel = FileTreeViewModel(
      tabs: tabs,
      workspace: workspace,
    )..languageServerClient = workspace.languageServerClient;
    await viewModel.refresh();
  });

  tearDown(() async {
    viewModel.dispose();
    tabs.dispose();
    await workspace.changeEventsController.close();
  });

  test('builds a folders-first tree and marks generated workspace entries as ignored', () {
    final rootChildren = viewModel.state.root.children;

    final folders = rootChildren.whereType<FileTreeFolderNode>().toList();
    expect(folders.map((node) => node.resource.path), ['.dart_tool', 'build', 'lib']);
    expect(folders.firstWhere((node) => node.resource.path == '.dart_tool').isIgnored, isTrue);
    expect(folders.firstWhere((node) => node.resource.path == 'build').isIgnored, isTrue);
    expect(folders.firstWhere((node) => node.resource.path == 'lib').isIgnored, isFalse);

    final files = rootChildren.whereType<FileTreeFileNode>().toList();
    expect(files.map((node) => node.resource.path), ['pubspec.yaml']);
  });

  test('exposes presentation metadata without requiring view-model queries', () async {
    workspace.addTextFile('assets/logo.png', 'binary');
    tabs.dirty = ['lib/main.dart'];
    tabs.notifyListeners();
    await viewModel.refresh();

    final assets = viewModel.state.root.children.whereType<FileTreeFolderNode>().singleWhere(
      (node) => node.resource.path == 'assets',
    );
    final logo = assets.children.whereType<FileTreeFileNode>().single;

    expect(logo.openable, isFalse);
    expect(viewModel.state.protectedEntries, containsAll(['lib', 'lib/main.dart', 'pubspec.yaml']));
    expect(viewModel.state.dirtyEntries, containsAll(['lib', 'lib/main.dart']));
  });

  test('creates text files in the selected folder and opens them', () async {
    await viewModel.createFile('lib', 'counter.dart');

    expect(workspace.files, contains('lib/counter.dart'));
    expect(tabs.openedFiles, ['lib/counter.dart']);
    expect(viewModel.state.operationError, isNull);
  });

  test('rejects destination collisions before mutations', () async {
    await viewModel.createFile('lib', 'main.dart');

    expect(viewModel.state.operationError, isNotNull);
    expect(operationLog, isEmpty);
  });

  test('renames in validate, save-all, LSP, physical-move order', () async {
    workspace.addTextFile('lib/old.dart', 'class Old {}');
    await viewModel.refresh();
    tabs.dirty = ['lib/main.dart'];

    await viewModel.renameFile('lib/old.dart', 'new.dart');

    expect(
      operationLog,
      [
        'save-all',
        'lsp:lib/old.dart->lib/new.dart',
        'move:lib/old.dart->lib/new.dart',
      ],
    );
    expect(workspace.files, contains('lib/new.dart'));
    expect(workspace.files, isNot(contains('lib/old.dart')));
    expect(workspace.fileExistChecks['lib/new.dart'], 2);
  });

  test('aborts rename before LSP and move when save-all fails', () async {
    workspace.addTextFile('lib/old.dart', 'class Old {}');
    await viewModel.refresh();
    tabs.saveError = StateError('save failed');

    await viewModel.renameFile('lib/old.dart', 'new.dart');

    expect(operationLog, ['save-all']);
    expect(workspace.files, contains('lib/old.dart'));
    expect(workspace.files, isNot(contains('lib/new.dart')));
    expect(viewModel.state.operationError, 'Workspace operation failed.');
  });

  test('moves after a willRenameFiles response error and reports a warning', () async {
    workspace
      ..folders.add('test')
      ..addTextFile('lib/old.dart', 'class Old {}');
    await viewModel.refresh();
    workspace.languageServerClient.renameError = StateError(
      'workspace/willRenameFiles failed: '
      '{code: -32001, message: request failed}',
    );

    await viewModel.moveEntry('lib/old.dart', 'test');

    expect(
      operationLog,
      [
        'save-all',
        'lsp:lib/old.dart->test/old.dart',
        'move:lib/old.dart->test/old.dart',
      ],
    );
    expect(workspace.files, contains('test/old.dart'));
    expect(workspace.files, isNot(contains('lib/old.dart')));
    expect(tabs.warnings, [
      'Imports could not be updated automatically; continuing with the move.',
    ]);
  });

  test('aborts a move for non-response LSP failures', () async {
    workspace
      ..folders.add('test')
      ..addTextFile('lib/old.dart', 'class Old {}');
    await viewModel.refresh();
    workspace.languageServerClient.renameError = StateError('transport failed');

    await viewModel.moveEntry('lib/old.dart', 'test');

    expect(
      operationLog,
      [
        'save-all',
        'lsp:lib/old.dart->test/old.dart',
      ],
    );
    expect(workspace.files, contains('lib/old.dart'));
    expect(workspace.files, isNot(contains('test/old.dart')));
    expect(viewModel.state.operationError, 'Workspace operation failed.');
  });

  test('protects main.dart, pubspec.yaml, and containing folders', () async {
    expect(viewModel.isProtectedFile('lib/main.dart'), isTrue);
    expect(viewModel.isProtectedFile('pubspec.yaml'), isTrue);
    expect(viewModel.isProtectedFolder('lib'), isTrue);

    await viewModel.deleteFile('lib/main.dart');
    await viewModel.deleteFolder('lib');

    expect(workspace.files, contains('lib/main.dart'));
    expect(viewModel.state.operationError, contains('required project file'));
  });

  test('refuses moving a folder into itself or a descendant', () async {
    workspace
      ..folders.add('assets')
      ..folders.add('assets/images');
    await viewModel.refresh();

    expect(
      () => viewModel.moveEntry('assets', 'assets/images'),
      throwsArgumentError,
    );
    expect(workspace.folders, contains('assets'));
    expect(operationLog, isEmpty);
  });

  test('focuses on a subfolder and exposes it as the root of the tree', () async {
    workspace
      ..addTextFile('my_project/pubspec.yaml', 'name: my_project')
      ..addTextFile('my_project/lib/main.dart', 'void main() {}')
      ..addTextFile('other_dir/other.dart', 'void main() {}');
    await viewModel.refresh();

    // Default root is ''
    expect(viewModel.state.focusedPath, '');
    expect(viewModel.state.root.resource.path, '');

    viewModel.focusPath('my_project');
    expect(viewModel.state.focusedPath, 'my_project');
    expect(viewModel.state.root.resource.path, 'my_project');

    // Root children should be my_project's children ('lib' and 'pubspec.yaml')
    final rootChildren = viewModel.state.root.children;
    expect(rootChildren.map((node) => node.resource.path), containsAll(['my_project/lib', 'my_project/pubspec.yaml']));
  });

  test('navigates up until the full filesystem (workspace root) is shown', () async {
    workspace
      ..addTextFile('a/b/c/project/pubspec.yaml', 'name: project')
      ..addTextFile('a/b/c/project/lib/main.dart', 'void main() {}');
    await viewModel.refresh();

    viewModel.focusPath('a/b/c/project');
    expect(viewModel.state.focusedPath, 'a/b/c/project');
    expect(viewModel.state.root.resource.path, 'a/b/c/project');

    // Navigate up to a/b/c
    viewModel.navigateUp();
    expect(viewModel.state.focusedPath, 'a/b/c');
    expect(viewModel.state.root.resource.path, 'a/b/c');

    // Navigate up to a/b
    viewModel.navigateUp();
    expect(viewModel.state.focusedPath, 'a/b');
    expect(viewModel.state.root.resource.path, 'a/b');

    // Navigate up to a
    viewModel.navigateUp();
    expect(viewModel.state.focusedPath, 'a');
    expect(viewModel.state.root.resource.path, 'a');

    // Navigate up to workspace root
    viewModel.navigateUp();
    expect(viewModel.state.focusedPath, '');
    expect(viewModel.state.root.resource.path, '');

    // Navigate up further does nothing
    viewModel.navigateUp();
    expect(viewModel.state.focusedPath, '');
    expect(viewModel.state.root.resource.path, '');
  });
}
