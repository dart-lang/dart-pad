// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/src/worker_client.dart'
    show FileAddedEvent, FileChangeEvent, FileModifiedEvent, FileRemovedEvent;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

class FakeWorkspaceChangeStream {
  final StreamController<FileChangeEvent> _changes = StreamController<FileChangeEvent>.broadcast();

  Stream<FileChangeEvent> get stream => _changes.stream;

  void emitAdd(String path) {
    _changes.add(FileAddedEvent(Uri.parse(path)));
  }

  void emitRemove(String path) {
    _changes.add(FileRemovedEvent(Uri.parse(path)));
  }

  void emitModify(String path) {
    _changes.add(FileModifiedEvent(Uri.parse(path)));
  }

  Future<void> close() => _changes.close();
}

void main() {
  group('RenameCache', () {
    test('tracks, overwrites, and consumes move intentions independently', () {
      final watcher = WorkspaceChangeWatcher(fileChanges: const Stream.empty());

      watcher
        ..addMoveIntention('a.dart', 'target.dart')
        ..addMoveIntention('replacement.dart', 'target.dart')
        ..addMoveIntention('x.dart', 'y.dart');

      expect(watcher.pendingMoves, {
        'target.dart': 'replacement.dart',
        'y.dart': 'x.dart',
      });
      expect(watcher.removeMoveIntention('target.dart'), 'replacement.dart');
      expect(watcher.removeMoveIntention('target.dart'), isNull);
      expect(watcher.removeMoveIntention('y.dart'), 'x.dart');
    });

    test('keeps move intentions isolated per watcher', () {
      final first = WorkspaceChangeWatcher(fileChanges: const Stream.empty());
      final second = WorkspaceChangeWatcher(fileChanges: const Stream.empty());

      first.addMoveIntention('a.dart', 'b.dart');

      expect(second.removeMoveIntention('b.dart'), isNull);
      expect(first.removeMoveIntention('b.dart'), 'a.dart');
    });
  });

  group('WorkspaceChangeWatcher', () {
    late FakeWorkspaceChangeStream stream;
    late WorkspaceChangeWatcher watcher;
    late List<WorkspaceChangeEvent> events;

    setUp(() {
      stream = FakeWorkspaceChangeStream();
      watcher = WorkspaceChangeWatcher(fileChanges: stream.stream)..watchFileSystem();
      events = [];
      watcher.events.listen(events.add);
    });

    tearDown(() async {
      await watcher.dispose();
      await stream.close();
    });

    test('forwards raw add, remove, and modify events', () async {
      final delivered = watcher.events.take(3).toList();
      stream
        ..emitAdd('added.dart')
        ..emitRemove('removed.dart')
        ..emitModify('modified.dart');
      await delivered;

      expect(
        events.map(_eventTuple),
        [
          (WorkspaceChangeEventType.add, 'added.dart', null),
          (WorkspaceChangeEventType.remove, 'removed.dart', null),
          (WorkspaceChangeEventType.modify, 'modified.dart', null),
        ],
      );
    });

    test('consolidates a move and suppresses its matching remove', () async {
      final delivered = watcher.events.first;
      watcher.addMoveIntention('old.dart', 'new.dart');
      stream
        ..emitAdd('new.dart')
        ..emitRemove('old.dart');
      await delivered;

      expect(events.map(_eventTuple), [
        (WorkspaceChangeEventType.move, 'new.dart', 'old.dart'),
      ]);
    });

    test('scopes remove suppression to one matching event', () async {
      final delivered = watcher.events.take(3).toList();
      watcher.addMoveIntention('old.dart', 'new.dart');
      stream
        ..emitAdd('new.dart')
        ..emitRemove('unrelated.dart')
        ..emitRemove('old.dart')
        ..emitRemove('old.dart');
      await delivered;

      expect(events.map(_eventTuple), [
        (WorkspaceChangeEventType.move, 'new.dart', 'old.dart'),
        (WorkspaceChangeEventType.remove, 'unrelated.dart', null),
        (WorkspaceChangeEventType.remove, 'old.dart', null),
      ]);
    });

    test('broadcasts events to multiple listeners', () async {
      final secondListenerEvents = <WorkspaceChangeEvent>[];
      watcher.events.listen(secondListenerEvents.add);
      final delivered = watcher.events.first;

      stream.emitAdd('file.dart');
      await delivered;

      expect(events, hasLength(1));
      expect(secondListenerEvents, hasLength(1));
    });

    test('does not subscribe to the raw event stream more than once', () async {
      watcher.watchFileSystem();
      final delivered = watcher.events.first;

      stream.emitAdd('single.dart');
      await delivered;

      expect(events, hasLength(1));
      expect(events.single.path, 'single.dart');
    });

    test('normalizes absolute SDK watcher URIs to workspace-relative paths', () async {
      await watcher.dispose();
      watcher = WorkspaceChangeWatcher(
        fileChanges: stream.stream,
        workspaceUri: Uri.parse('file:///workspace/42/'),
      )..watchFileSystem();
      events = [];
      watcher.events.listen(events.add);
      final delivered = watcher.events.first;

      stream
        ..emitAdd('file:///somewhere-else/ignored.dart')
        ..emitAdd('file:///workspace/42/lib/main.dart');
      await delivered;

      expect(events.map(_eventTuple), [
        (WorkspaceChangeEventType.add, 'lib/main.dart', null),
      ]);
    });

    test('ready waits for the SDK watcher readiness signal', () async {
      await watcher.dispose();
      final sourceReady = Completer<void>();
      watcher = WorkspaceChangeWatcher(
        fileChanges: stream.stream,
        sourceReady: sourceReady.future,
      );

      var completed = false;
      watcher.watchFileSystem();
      final start = watcher.ready.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      sourceReady.complete();
      await start;
      expect(completed, isTrue);
    });
  });
}

(WorkspaceChangeEventType, String, String?) _eventTuple(
  WorkspaceChangeEvent event,
) => (event.type, event.path, event.oldPath);
