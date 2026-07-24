// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_preview/features/filetree/file_tree_editor_delegate.dart';
import 'package:dartpad_preview/features/filetree/file_tree_models.dart';
import 'package:dartpad_preview/features/filetree/file_tree_view_model.dart';
import 'package:dartpad_preview/features/shared/app_event_bus.dart';
import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
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

/// Controllable workspace watcher used by the file-tree view-model tests.
final class FakeWatcher implements WorkspaceChangeWatcher {
  final StreamController<WorkspaceChangeEvent> controller = StreamController<WorkspaceChangeEvent>.broadcast(
    sync: true,
  );

  @override
  Stream<WorkspaceChangeEvent> get events => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
final class FakeWorkspaceController implements WorkspaceController {
  /// Creates an empty workspace that appends operations to [operationLog].
  FakeWorkspaceController(this.operationLog) : languageServerClient = FakeLanguageServerClient(operationLog);

  final List<String> operationLog;
  final Map<String, Uint8List> files = {};
  final Set<String> folders = {''};
  final Map<String, int> fileExistChecks = {};
  int textWriteCount = 0;

  @override
  final FakeLanguageServerClient languageServerClient;

  @override
  final FakeWatcher watcher = FakeWatcher();

  @override
  Workspace get workspace => throw UnimplementedError('Tests use the WorkspaceApi delegates.');

  @override
  Uri get workspaceUri => Uri.parse('file:///workspace/');

  @override
  Uri get workspaceFolder => workspaceUri;

  @override
  WorkspaceFolder get root => WorkspaceFolder(workspace: this, path: '');

  @override
  int get id => 1;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Exercises file-tree state transitions and workspace mutations.
void main() {
  late List<String> operationLog;
  late FakeTabs tabs;
  late FakeWorkspaceController workspace;
  late AppEventBus events;
  late List<LogEvent> logs;
  late StreamSubscription<LogEvent> logSubscription;
  late FileTreeViewModel viewModel;

  setUp(() async {
    operationLog = [];
    tabs = FakeTabs(operationLog);
    workspace = FakeWorkspaceController(operationLog)
      ..addTextFile('lib/main.dart', 'void main() {}')
      ..addTextFile('pubspec.yaml', 'name: test')
      ..addTextFile('.dart_tool/package_config.json', '{}')
      ..addTextFile('build/output.js', '');
    events = AppEventBus();
    logs = [];
    logSubscription = events.on<LogEvent>().listen(logs.add);
    viewModel = FileTreeViewModel(
      tabs: tabs,
      workspace: workspace,
      events: events,
    );
    await viewModel.refresh();
  });

  tearDown(() async {
    viewModel.dispose();
    tabs.dispose();
    await logSubscription.cancel();
    await workspace.watcher.controller.close();
    await events.dispose();
  });

  test('builds a folders-first tree and hides generated workspace entries', () {
    final rootChildren = viewModel.state.root.children;

    expect(rootChildren.first, isA<FileTreeFolderNode>());
    expect(rootChildren.whereType<FileTreeFolderNode>().map((node) => node.resource.path), ['lib']);
    expect(rootChildren.whereType<FileTreeFileNode>().map((node) => node.resource.path), ['pubspec.yaml']);
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
    viewModel
      ..selectFolder('lib')
      ..startAddingFile()
      ..setNewEntryName('counter.dart');

    await viewModel.confirmAddFile();

    expect(workspace.files, contains('lib/counter.dart'));
    expect(tabs.openedFiles, ['lib/counter.dart']);
    expect(viewModel.state.operationError, isNull);
  });

  test('coalesces Enter submit and the immediately following create blur', () async {
    viewModel
      ..selectFolder('lib')
      ..startAddingFile()
      ..setNewEntryName('single.dart');

    final enterSubmit = viewModel.confirmAddFile();
    final blurSubmit = viewModel.handleCreateBlur();
    await Future.wait([enterSubmit, blurSubmit]);

    expect(workspace.textWriteCount, 1);
    expect(workspace.files, contains('lib/single.dart'));
    expect(tabs.openedFiles, ['lib/single.dart']);
  });

  test('ignores a late create blur after the input was removed', () async {
    viewModel
      ..selectFolder('lib')
      ..startAddingFile()
      ..setNewEntryName('late-blur.dart');

    await viewModel.confirmAddFile();
    final stateAfterCreate = viewModel.state;
    await viewModel.handleCreateBlur();

    expect(viewModel.state.creatingEntry, stateAfterCreate.creatingEntry);
    expect(workspace.textWriteCount, 1);
    expect(tabs.openedFiles, ['lib/late-blur.dart']);
  });

  test('rejects invalid names and destination collisions before mutations', () async {
    viewModel
      ..selectFolder('lib')
      ..startAddingFile()
      ..setNewEntryName('../bad.dart');
    await viewModel.confirmAddFile();
    expect(viewModel.state.nameValidationError, isNotNull);

    viewModel.setNewEntryName('main.dart');
    await viewModel.confirmAddFile();

    expect(
      viewModel.state.operationError,
      'A file or folder already exists at "lib/main.dart".',
    );
    expect(operationLog, isEmpty);
  });

  test('renames in validate, save-all, LSP, physical-move order', () async {
    workspace.addTextFile('lib/old.dart', 'class Old {}');
    await viewModel.refresh();
    tabs.dirty = ['lib/main.dart'];

    viewModel
      ..startRenamingFile('lib/old.dart')
      ..setRenameValue('new.dart');
    await viewModel.confirmRenameFile('lib/old.dart');

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

    viewModel
      ..startRenamingFile('lib/old.dart')
      ..setRenameValue('new.dart');
    await viewModel.confirmRenameFile('lib/old.dart');

    expect(operationLog, ['save-all']);
    expect(workspace.files, contains('lib/old.dart'));
    expect(workspace.files, isNot(contains('lib/new.dart')));
    expect(viewModel.state.operationError, 'Workspace operation failed.');
    await pumpEventQueue();
    expect(logs.single.error, same(tabs.saveError));
    expect(logs.single.stackTrace, isNotNull);
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

    viewModel.startDraggingFile('lib/old.dart');
    await viewModel.dropIntoFolder('test');

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
    await pumpEventQueue();
    expect(logs.single.level, Level.WARNING);
    expect(logs.single.error, same(workspace.languageServerClient.renameError));
  });

  test('aborts a move for non-response LSP failures', () async {
    workspace
      ..folders.add('test')
      ..addTextFile('lib/old.dart', 'class Old {}');
    await viewModel.refresh();
    workspace.languageServerClient.renameError = StateError('transport failed');

    viewModel.startDraggingFile('lib/old.dart');
    await viewModel.dropIntoFolder('test');

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

  test('refuses dragging a folder into itself or a descendant', () async {
    workspace
      ..folders.add('assets')
      ..folders.add('assets/images');
    await viewModel.refresh();

    viewModel.startDraggingFolder('assets');
    viewModel.markDropTarget('assets/images');

    expect(viewModel.state.dropTargetFolder, isNull);
    await viewModel.dropIntoFolder('assets/images');
    expect(workspace.folders, contains('assets'));
    expect(operationLog, isEmpty);
  });
}
