// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad/src/worker_client.dart'
    show FileAddedEvent, FileChangeEvent, FileModifiedEvent, FileRemovedEvent;
import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A minimal fake [Workspace] for testing. Supports a configurable set of
/// files that "exist" and provides a controllable event stream.
class FakeWorkspace implements WorkspaceApi {
  final Set<String> _existingFiles = {};
  final StreamController<FileChangeEvent> _changesController = StreamController<FileChangeEvent>.broadcast(sync: true);

  Stream<FileChangeEvent> get fileChanges => _changesController.stream;

  @override
  Uri get workspaceFolder => Uri.parse('file:///workspace/');

  @override
  int get id => 0;

  void addFile(String path) => _existingFiles.add(path);
  void removeFile(String path) => _existingFiles.remove(path);

  @override
  Future<bool> fileExist(String uri) async => _existingFiles.contains(uri);

  @override
  Future<bool> folderExist(String uri) async => false;

  void close() {
    _changesController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A minimal stub for [LanguageServerClient] that only implements the methods
/// used by [TabsController] (namely [setDisplayFileHandler]).
class FakeLanguageServerClient implements LanguageServerClient {
  Future<void> Function(String)? displayFileHandler;

  @override
  void setDisplayFileHandler(Future<void> Function(String)? handler) {
    displayFileHandler = handler;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A fake [WorkspaceController] that bypasses the real constructor
/// (which requires a real [LanguageServer] and CodeMirror JS interop).
class FakeWorkspaceController implements WorkspaceController {
  FakeWorkspaceController({required this.fakeWorkspace}) {
    watcher = WorkspaceChangeWatcher(fileChanges: fakeWorkspace.fileChanges)..watchFileSystem();
    languageServerClient = FakeLanguageServerClient();
  }

  final FakeWorkspace fakeWorkspace;

  @override
  Workspace get workspace => throw UnimplementedError('Use fakeWorkspace in tests');

  @override
  late final WorkspaceChangeWatcher watcher;

  @override
  late final LanguageServerClient languageServerClient;

  @override
  Uri get workspaceUri => fakeWorkspace.workspaceFolder;

  @override
  WorkspaceFolder get root => WorkspaceFolder(workspace: this, path: '');

  @override
  void addMoveIntention(String oldPath, String newPath) {
    watcher.addMoveIntention(oldPath, newPath);
  }

  // WorkspaceApi delegates
  @override
  int get id => fakeWorkspace.id;
  @override
  Uri get workspaceFolder => fakeWorkspace.workspaceFolder;
  @override
  Future<bool> fileExist(String uri) => fakeWorkspace.fileExist(uri);
  @override
  Future<bool> folderExist(String uri) => fakeWorkspace.folderExist(uri);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A concrete [EditorTab] for testing that tracks lifecycle calls.
class TestTab extends EditorTab<String> {
  TestTab(
    super.path, {
    this.testKeepAlive = false,
    this.dirty = false,
    this.saveError,
    this.eventLog,
  });

  final bool testKeepAlive;
  bool dirty;
  final Error? saveError;
  final List<String>? eventLog;

  final List<String> lifecycleLog = [];
  final StreamController<void> updates = StreamController<void>.broadcast(sync: true);

  @override
  bool get keepAlive => testKeepAlive;

  @override
  bool get hasUnsavedChanges => dirty;

  @override
  void onActivate() => _record('activate');

  @override
  void onDeactivate() => _record('deactivate');

  @override
  void onClose() => _record('close');

  @override
  void dispose() => _record('dispose');

  @override
  Stream<void> get onUpdate => updates.stream;

  void notifyUpdate() => updates.add(null);

  @override
  Future<void> save() async {
    _record('save');
    if (saveError != null) {
      throw saveError!;
    }
    dirty = false;
  }

  @override
  void discardUnsavedChanges() {
    _record('discardUnsavedChanges');
    dirty = false;
  }

  void _record(String event) {
    lifecycleLog.add(event);
    eventLog?.add('$path:$event');
  }

  @override
  String build() => 'TestTab($path)';
}

/// A simple [EditorTabAdapter] that creates [TestTab]s.
class TestTabAdapter extends EditorTabAdapter<String> {
  TestTabAdapter({
    this.keepAlive = false,
    this.dirty = false,
    this.saveError,
    this.creationGate,
  });

  bool keepAlive;
  bool dirty;
  Error? saveError;
  Completer<void>? creationGate;
  int creationCount = 0;
  final Completer<void> creationStarted = Completer<void>();
  final List<String> eventLog = [];

  /// Tabs created by this adapter, keyed by path.
  final Map<String, TestTab> createdTabs = {};

  @override
  Future<EditorTab<String>?> createTab(String path) async {
    creationCount++;
    if (!creationStarted.isCompleted) {
      creationStarted.complete();
    }
    await creationGate?.future;
    final tab = TestTab(
      path,
      testKeepAlive: keepAlive,
      dirty: dirty,
      saveError: saveError,
      eventLog: eventLog,
    );
    createdTabs[path] = tab;
    return tab;
  }
}

/// A concrete implementation of [TabsController] that records [didUpdate]
/// and [didSaveTabs] calls for test assertions.
class TestTabsController with TabsController<String> {
  final List<bool?> updateLog = [];
  final List<List<String>> saveLog = [];

  @override
  void didUpdate({bool? isSaving}) {
    updateLog.add(isSaving);
  }

  @override
  Future<void> didSaveTabs(List<String> paths) async {
    saveLog.add(List.of(paths));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeWorkspace workspace;
  late FakeWorkspaceController controller;
  late TestTabAdapter adapter;
  late TestTabsController tabs;

  setUp(() {
    workspace = FakeWorkspace();
    controller = FakeWorkspaceController(fakeWorkspace: workspace);
    adapter = TestTabAdapter();
    tabs = TestTabsController();
    tabs.init(workspaceController: controller, adapters: [adapter]);
  });

  tearDown(() async {
    tabs.disposeAllTabs();
    await controller.watcher.dispose();
    workspace.close();
  });

  // -- Helpers --

  /// Opens a file after ensuring it "exists" in the fake workspace.
  Future<void> openExisting(String path) async {
    workspace.addFile(path);
    await tabs.openFile(path);
  }

  Future<void> emitWorkspaceEvent(Map<String, String> event) async {
    final delivered = controller.watcher.events.first;
    final uri = Uri.parse(event['path']!);
    if (event['type'] == 'add') {
      workspace._changesController.add(FileAddedEvent(uri));
    } else if (event['type'] == 'remove') {
      workspace._changesController.add(FileRemovedEvent(uri));
    } else if (event['type'] == 'modify') {
      workspace._changesController.add(FileModifiedEvent(uri));
    }
    await delivered;
  }

  group('openFile', () {
    test('opens a new tab and sets it as active', () async {
      await openExisting('main.dart');

      expect(tabs.openTabs, hasLength(1));
      expect(tabs.activeFile, 'main.dart');
      expect(tabs.activeTab?.path, 'main.dart');
      expect(adapter.createdTabs['main.dart']!.lifecycleLog, ['activate']);
    });

    test('does nothing for a file that does not exist', () async {
      await tabs.openFile('ghost.dart');

      expect(tabs.openTabs, isEmpty);
      expect(tabs.activeFile, '');
    });

    test('reuses existing tab if already open', () async {
      await openExisting('a.dart');
      await openExisting('b.dart');
      await openExisting('a.dart'); // should not create a second tab

      expect(tabs.openTabs, hasLength(2));
      expect(tabs.activeFile, 'a.dart');
    });

    test('restores a keepAlive tab from cache', () async {
      adapter.keepAlive = true;

      await openExisting('a.dart');
      await openExisting('b.dart');
      tabs.closeTab('a.dart'); // kept alive

      expect(tabs.openTabs, hasLength(1));
      expect(tabs.getTab('a.dart'), isNotNull, reason: 'kept-alive tab should still be accessible via getTab');

      await openExisting('a.dart');
      expect(tabs.openTabs, hasLength(2));
      expect(tabs.activeFile, 'a.dart');
    });

    test('coalesces concurrent requests for the same file', () async {
      adapter.creationGate = Completer<void>();
      workspace.addFile('slow.dart');

      final firstOpen = tabs.openFile('slow.dart');
      final secondOpen = tabs.openFile('slow.dart');
      await adapter.creationStarted.future;

      expect(adapter.creationCount, 1);
      adapter.creationGate!.complete();
      await Future.wait([firstOpen, secondOpen]);
      expect(tabs.openTabs.map((tab) => tab.path), ['slow.dart']);
    });

    test('disposes a tab deleted while its adapter is still loading', () async {
      adapter.creationGate = Completer<void>();
      workspace.addFile('deleted.dart');

      final opening = tabs.openFile('deleted.dart');
      await adapter.creationStarted.future;
      workspace.removeFile('deleted.dart');
      await emitWorkspaceEvent(
        {'type': 'remove', 'path': 'deleted.dart'},
      );

      adapter.creationGate!.complete();
      await opening;
      expect(tabs.openTabs, isEmpty);
      final deletedTab = adapter.createdTabs['deleted.dart']!;
      expect(deletedTab.lifecycleLog, ['dispose']);

      tabs.updateLog.clear();
      deletedTab.notifyUpdate();
      expect(tabs.updateLog, isEmpty);
    });

    test('opens a workspace-relative file requested by the language server', () async {
      workspace.addFile('lib/main.dart');
      final languageServer = controller.languageServerClient as FakeLanguageServerClient;

      await languageServer.displayFileHandler!(
        'file:///workspace/lib/main.dart',
      );

      expect(tabs.activeFile, 'lib/main.dart');
    });
  });

  group('switchFile', () {
    test('switches tabs in lifecycle order', () async {
      await openExisting('a.dart');
      await openExisting('b.dart');

      adapter.eventLog.clear();
      tabs.switchFile('a.dart');

      expect(tabs.activeFile, 'a.dart');
      expect(adapter.eventLog, ['b.dart:deactivate', 'a.dart:activate']);
    });

    test('ignores the active file and files that are not open', () async {
      await openExisting('a.dart');
      final before = tabs.updateLog.length;

      tabs.switchFile('a.dart');
      tabs.switchFile('nonexistent.dart');

      expect(tabs.updateLog.length, before);
    });
  });

  group('closeTab', () {
    test('closes and disposes a non-active tab without deactivating it', () async {
      await openExisting('a.dart');
      await openExisting('b.dart');

      final tabA = adapter.createdTabs['a.dart']!;
      tabA.lifecycleLog.clear();
      tabs.closeTab('a.dart');

      expect(tabs.openTabs.map((tab) => tab.path), ['b.dart']);
      expect(tabA.lifecycleLog, ['close', 'dispose']);
    });

    test('does not close the last remaining tab', () async {
      await openExisting('only.dart');
      tabs.closeTab('only.dart');

      expect(tabs.openTabs, hasLength(1));
      expect(tabs.activeFile, 'only.dart');
    });

    test('activates the next tab when closing the active tab', () async {
      await openExisting('a.dart');
      await openExisting('b.dart');
      await openExisting('c.dart');
      tabs.switchFile('b.dart');

      tabs.closeTab('b.dart');
      expect(tabs.activeFile, 'c.dart');
    });

    test('activates the previous tab when closing the last tab', () async {
      await openExisting('a.dart');
      await openExisting('b.dart');
      tabs.switchFile('b.dart');

      tabs.closeTab('b.dart');
      expect(tabs.activeFile, 'a.dart');
    });

    test('keepAlive tab is cached instead of disposed', () async {
      adapter.keepAlive = true;

      await openExisting('a.dart');
      await openExisting('b.dart');

      final tabA = adapter.createdTabs['a.dart']!..lifecycleLog.clear();
      tabs.closeTab('a.dart');

      expect(tabA.lifecycleLog, ['close']);
      expect(tabs.getTab('a.dart'), same(tabA));
    });
  });

  group('saveTab', () {
    test('saves a dirty tab within a saving-state transition', () async {
      adapter.dirty = true;

      await openExisting('dirty.dart');
      tabs.updateLog.clear();
      final tab = adapter.createdTabs['dirty.dart']!..lifecycleLog.clear();
      await tabs.saveTab('dirty.dart');

      expect(tab.lifecycleLog, ['save']);
      expect(tabs.saveLog, [
        ['dirty.dart'],
      ]);
      expect(tabs.updateLog, [true, false]);
    });

    test('ignores clean and unknown tabs', () async {
      await openExisting('clean.dart');
      final tab = adapter.createdTabs['clean.dart']!..lifecycleLog.clear();
      await tabs.saveTab('clean.dart');
      await tabs.saveTab('nonexistent.dart');

      expect(tab.lifecycleLog, isEmpty);
      expect(tabs.saveLog, isEmpty);
    });

    test('clears the saving state when saving fails', () async {
      adapter
        ..dirty = true
        ..saveError = StateError('save failed');
      await openExisting('d.dart');
      tabs.updateLog.clear();

      await expectLater(tabs.saveTab('d.dart'), throwsStateError);
      expect(tabs.updateLog, [true, false]);
      expect(tabs.saveLog, isEmpty);
    });
  });

  group('saveAllTabs', () {
    test('saves all dirty tabs', () async {
      adapter.dirty = true;

      await openExisting('a.dart');
      await openExisting('b.dart');
      adapter.createdTabs['a.dart']!.lifecycleLog.clear();
      adapter.createdTabs['b.dart']!.lifecycleLog.clear();

      await tabs.saveAllTabs();

      expect(adapter.createdTabs['a.dart']!.lifecycleLog, ['save']);
      expect(adapter.createdTabs['b.dart']!.lifecycleLog, ['save']);
      expect(tabs.saveLog.last, unorderedEquals(['a.dart', 'b.dart']));
    });
  });

  test('tracks and discards only dirty tabs', () async {
    adapter.dirty = true;
    await openExisting('dirty.dart');
    await openExisting('clean.dart');
    adapter.createdTabs['clean.dart']!.dirty = false;

    expect(tabs.hasUnsavedChanges, isTrue);
    expect(tabs.dirtyFiles, ['dirty.dart']);

    tabs.discardUnsavedChanges();

    expect(
      adapter.createdTabs['dirty.dart']!.lifecycleLog,
      contains('discardUnsavedChanges'),
    );
    expect(
      adapter.createdTabs['clean.dart']!.lifecycleLog,
      isNot(contains('discardUnsavedChanges')),
    );
    expect(tabs.hasUnsavedChanges, isFalse);
  });

  test('tab update events notify the controller', () async {
    await openExisting('main.dart');
    tabs.updateLog.clear();

    adapter.createdTabs['main.dart']!.notifyUpdate();

    expect(tabs.updateLog, [null]);
  });

  group('workspace events', () {
    test('move event renames the open tab path', () async {
      await openExisting('old.dart');
      controller.addMoveIntention('old.dart', 'new.dart');
      workspace.addFile('new.dart');

      // Simulate the filesystem event sequence.
      await emitWorkspaceEvent(
        {'type': 'add', 'path': 'new.dart'},
      );

      expect(tabs.activeFile, 'new.dart');
      expect(tabs.openTabs.first.path, 'new.dart');
    });

    test('move event keeps the update subscription associated with the renamed tab', () async {
      await openExisting('old.dart');
      await openExisting('other.dart');
      final movedTab = adapter.createdTabs['old.dart']!;

      controller.addMoveIntention('old.dart', 'new.dart');
      workspace.addFile('new.dart');
      await emitWorkspaceEvent(
        {'type': 'add', 'path': 'new.dart'},
      );
      tabs.closeTab('new.dart');
      tabs.updateLog.clear();

      movedTab.notifyUpdate();

      expect(tabs.updateLog, isEmpty);
    });

    test('move event renames a keepAlive tab in the cache', () async {
      adapter.keepAlive = true;

      await openExisting('a.dart');
      await openExisting('b.dart');
      tabs.closeTab('a.dart'); // now in keepAlive cache

      controller.addMoveIntention('a.dart', 'a2.dart');
      workspace.addFile('a2.dart');
      await emitWorkspaceEvent(
        {'type': 'add', 'path': 'a2.dart'},
      );

      // The kept-alive tab should be findable under the new path.
      expect(tabs.getTab('a2.dart'), isNotNull);
      expect(tabs.getTab('a.dart'), isNull);
    });

    test('remove event disposes the active tab and activates its neighbor', () async {
      await openExisting('a.dart');
      await openExisting('b.dart');
      tabs.switchFile('a.dart');
      final tabA = adapter.createdTabs['a.dart']!..lifecycleLog.clear();

      await emitWorkspaceEvent(
        {'type': 'remove', 'path': 'a.dart'},
      );

      expect(tabs.openTabs.map((tab) => tab.path), ['b.dart']);
      expect(tabs.activeFile, 'b.dart');
      expect(tabA.lifecycleLog, ['deactivate', 'close', 'dispose']);
    });

    test('remove event on keepAlive tab disposes it', () async {
      adapter.keepAlive = true;

      await openExisting('a.dart');
      await openExisting('b.dart');
      tabs.closeTab('a.dart');
      final tabA = adapter.createdTabs['a.dart']!..lifecycleLog.clear();

      await emitWorkspaceEvent(
        {'type': 'remove', 'path': 'a.dart'},
      );

      expect(tabA.lifecycleLog, ['close', 'dispose']);
      expect(tabs.getTab('a.dart'), isNull);
    });
  });

  group('disposeAllTabs', () {
    test('disposes all open and keepAlive tabs', () async {
      adapter.keepAlive = true;

      await openExisting('a.dart');
      await openExisting('b.dart');
      tabs.closeTab('a.dart'); // goes to keepAlive
      adapter.createdTabs['a.dart']!.lifecycleLog.clear();
      adapter.createdTabs['b.dart']!.lifecycleLog.clear();

      tabs.disposeAllTabs();

      expect(adapter.createdTabs['a.dart']!.lifecycleLog, ['dispose']);
      expect(adapter.createdTabs['b.dart']!.lifecycleLog, ['dispose']);
    });

    test('cancels tab update subscriptions', () async {
      await openExisting('a.dart');
      final tab = adapter.createdTabs['a.dart']!;

      tabs.disposeAllTabs();
      tabs.updateLog.clear();
      tab.notifyUpdate();

      expect(tabs.updateLog, isEmpty);
    });
  });
}
