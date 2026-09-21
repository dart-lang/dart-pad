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
  Future<void> openWorkspaceFile(String path) async {
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
          (path: folder.substring(prefix.length), type: 'folder'),
      for (final file in files.keys)
        if (file.startsWith(prefix) && (recursive || !file.substring(prefix.length).contains('/')))
          (path: file.substring(prefix.length), type: 'file'),
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
      rootPath: '',
    )..languageServerClient = workspace.languageServerClient;
    await viewModel.refresh();
  });

  tearDown(() async {
    viewModel.dispose();
    tabs.dispose();
    await workspace.changeEventsController.close();
  });

  group('project root boundary', () {
    setUp(() async {
      viewModel.dispose();
      workspace
        ..addTextFile('example/pubspec.yaml', 'name: example')
        ..addTextFile('example/lib/main.dart', 'void main() {}')
        ..addTextFile('example/assets/notes.txt', 'notes')
        ..addTextFile('example-other/notes.txt', 'outside');
      viewModel = FileTreeViewModel(
        tabs: tabs,
        workspace: workspace,
        rootPath: 'example',
      )..languageServerClient = workspace.languageServerClient;
    });

    test('starts scoped and loads only the project subtree', () async {
      expect(viewModel.state.root.resource.path, 'example');
      expect(viewModel.state.focusedPath, 'example');
      await viewModel.refresh();
      expect(viewModel.state.root.children.map((node) => node.resource.path), [
        'example/assets',
        'example/lib',
        'example/pubspec.yaml',
      ]);
      expect(viewModel.state.root.exists('lib/main.dart'), isFalse);
    });

    test('focus rejects ancestors, siblings and traversal', () async {
      await viewModel.refresh();
      for (final path in ['', '..', 'example/..', 'example-other', '/example', r'example\..']) {
        viewModel.focusPath(path);
        expect(viewModel.state.focusedPath, 'example', reason: path);
        expect(viewModel.state.root.resource.path, 'example', reason: path);
        expect(viewModel.state.operationError, contains('outside the project root'));
      }
    });

    test('deleted focus falls back to project root', () async {
      await viewModel.refresh();
      viewModel.focusPath('example/assets');
      await viewModel.deleteFolder('example/assets');
      expect(viewModel.state.focusedPath, 'example');
      expect(viewModel.state.root.resource.path, 'example');
    });

    final invalidOperations = <String, Future<void> Function(FileTreeViewModel)>{
      'create file outside': (model) => model.createFile('', 'outside.txt'),
      'create folder outside': (model) => model.createFolder('', 'outside'),
      'create with traversal': (model) => model.createFile('example', '../outside.txt'),
      'create folder with traversal': (model) => model.createFolder('example', '../outside'),
      'rename outside file': (model) => model.renameFile('example-other/notes.txt', 'new.txt'),
      'rename outside folder': (model) => model.renameFolder('example-other', 'new'),
      'rename file out of root': (model) => model.renameFile('example/assets/notes.txt', '../../outside.txt'),
      'rename folder out of root': (model) => model.renameFolder('example/assets', '../outside'),
      'delete outside file': (model) => model.deleteFile('example-other/notes.txt'),
      'delete ancestor': (model) => model.deleteFolder(''),
      'move out of root': (model) => model.moveEntry('example/assets/notes.txt', ''),
      'move into root from outside': (model) => model.moveEntry('example-other/notes.txt', 'example'),
    };
    for (final operation in invalidOperations.entries) {
      test('rejects ${operation.key} before saving, LSP or filesystem mutations', () async {
        final files = Map<String, Uint8List>.of(workspace.files);
        final folders = Set<String>.of(workspace.folders);
        await operation.value(viewModel);
        expect(viewModel.state.operationError, isNotNull);
        expect(workspace.files, files);
        expect(workspace.folders, folders);
        expect(operationLog, isEmpty);
        expect(tabs.openedFiles, isEmpty);
      });
    }

    test('allows creating, renaming, moving and deleting within root', () async {
      await viewModel.createFolder('example', 'new');
      await viewModel.createFile('example/new', 'file.txt');
      await viewModel.renameFile('example/new/file.txt', 'renamed.txt');
      await viewModel.moveEntry('example/new/renamed.txt', 'example/assets');
      expect(workspace.files, contains('example/assets/renamed.txt'));
      await viewModel.deleteFile('example/assets/renamed.txt');
      await viewModel.deleteFolder('example/new');
      expect(viewModel.state.operationError, isNull);
      expect(workspace.files, isNot(contains('example/assets/renamed.txt')));
      expect(workspace.folders, isNot(contains('example/new')));
    });

    test('allows deleting the whole project without changing files outside it', () async {
      await viewModel.deleteFolder('example');
      expect(workspace.files.keys.where((path) => path.startsWith('example/')), isEmpty);
      expect(workspace.folders, isNot(contains('example')));
      expect(workspace.files, contains('lib/main.dart'));
      expect(workspace.files, contains('example-other/notes.txt'));
      expect(viewModel.state.root.children, isEmpty);
      expect(viewModel.state.operationError, isNull);
    });

    test('tree actions cannot open files outside root', () async {
      await viewModel.actions.openWorkspaceFile('example-other/notes.txt');
      expect(tabs.openedFiles, isEmpty);
      expect(viewModel.state.operationError, contains('outside the project root'));
    });
  });

  test('builds a folders-first tree and marks top-level dot entries as ignored', () async {
    final rootChildren = viewModel.state.root.children;

    final folders = rootChildren.whereType<FileTreeFolderNode>().toList();
    expect(folders.map((node) => node.resource.path), ['.dart_tool', 'build', 'lib']);
    expect(folders.firstWhere((node) => node.resource.path == '.dart_tool').isIgnored, isTrue);
    expect(folders.firstWhere((node) => node.resource.path == 'build').isIgnored, isFalse);
    expect(folders.firstWhere((node) => node.resource.path == 'lib').isIgnored, isFalse);

    final files = rootChildren.whereType<FileTreeFileNode>().toList();
    expect(files.map((node) => node.resource.path), ['pubspec.yaml']);

    workspace
      ..addTextFile('.env', '')
      ..addTextFile('packages/example/.dart_tool/package_config.json', '{}')
      ..addTextFile('packages/example/build/output.js', '');
    await viewModel.refresh();

    final refreshedRoot = viewModel.state.root;
    final hiddenFile = refreshedRoot.children.whereType<FileTreeFileNode>().firstWhere(
      (node) => node.resource.path == '.env',
    );
    final hiddenFolder = refreshedRoot.findFolder('.dart_tool')!;
    expect(hiddenFile.isIgnored, isTrue);
    expect(hiddenFolder.isIgnored, isTrue);
    expect(hiddenFolder.children.single.isIgnored, isTrue);
    expect(refreshedRoot.findFolder('packages/example/.dart_tool')?.isIgnored, isFalse);
    expect(refreshedRoot.findFolder('packages/example/build')?.isIgnored, isFalse);
    expect(viewModel.state.root.findFolder('packages/example')?.isIgnored, isFalse);
  });

  test('marks text files and supported images as openable', () async {
    for (final fileName in ['logo.png', 'photo.JPG', 'animation.gif', 'favicon.ico', 'logo.svg', 'image.webp']) {
      workspace.addTextFile('assets/$fileName', 'binary');
    }
    workspace
      ..addTextFile('assets/photo.bmp', 'binary')
      ..addTextFile('assets/photo.avif', 'binary');
    tabs.dirty = ['lib/main.dart'];
    tabs.notifyListeners();
    await viewModel.refresh();

    final assets = viewModel.state.root.children.whereType<FileTreeFolderNode>().singleWhere(
      (node) => node.resource.path == 'assets',
    );
    final files = assets.children.whereType<FileTreeFileNode>();

    for (final file in files.where(
      (file) => !file.resource.path.endsWith('.bmp') && !file.resource.path.endsWith('.avif'),
    )) {
      expect(file.openable, isTrue, reason: file.resource.path);
    }
    expect(files.singleWhere((file) => file.resource.path.endsWith('.bmp')).openable, isFalse);
    expect(files.singleWhere((file) => file.resource.path.endsWith('.avif')).openable, isFalse);
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

  test('reports moving a folder into itself or a descendant as an operation error', () async {
    workspace
      ..folders.add('assets')
      ..folders.add('assets/images');
    await viewModel.refresh();

    await viewModel.moveEntry('assets', 'assets/images');

    expect(workspace.folders, contains('assets'));
    expect(operationLog, isEmpty);
    expect(viewModel.state.operationError, 'Workspace operation failed.');
    expect(viewModel.state.busy, isFalse);
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
}
