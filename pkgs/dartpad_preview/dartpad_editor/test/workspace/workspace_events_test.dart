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

class FakeWorkspaceEventsApi with WorkspaceResourceEventsMixin implements WorkspaceResourceApi {
  FakeWorkspaceEventsApi({required this.rawFileChanges, this._fileChangesReady});

  @override
  final Stream<FileChangeEvent> rawFileChanges;

  final Future<void>? _fileChangesReady;

  @override
  Future<void> get changeEventsReady => _fileChangesReady ?? Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('RenameCache', () {
    test('tracks, overwrites, and consumes move intentions independently', () {
      final api = FakeWorkspaceEventsApi(rawFileChanges: const Stream.empty());

      api.addMoveIntention('a.dart', 'target.dart');
      api.addMoveIntention('replacement.dart', 'target.dart');
      api.addMoveIntention('x.dart', 'y.dart');

      expect(api.pendingMoves, {
        'target.dart': 'replacement.dart',
        'y.dart': 'x.dart',
      });
      expect(api.pendingMoves.remove('target.dart'), 'replacement.dart');
      expect(api.pendingMoves.remove('target.dart'), isNull);
      expect(api.pendingMoves.remove('y.dart'), 'x.dart');
    });
  });

  group('WorkspaceResourceApi Event Reconciliation', () {
    late FakeWorkspaceChangeStream stream;
    late FakeWorkspaceEventsApi api;
    late List<WorkspaceChangeEvent> events;

    setUp(() {
      stream = FakeWorkspaceChangeStream();
      api = FakeWorkspaceEventsApi(rawFileChanges: stream.stream);
      events = [];
      api.changeEvents.listen(events.add);
    });

    tearDown(() async {
      await stream.close();
    });

    test('forwards raw add, remove, and modify events', () async {
      final delivered = api.changeEvents.take(3).toList();
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
      final delivered = api.changeEvents.first;
      api.addMoveIntention('old.dart', 'new.dart');
      stream
        ..emitAdd('new.dart')
        ..emitRemove('old.dart');
      await delivered;

      expect(events.map(_eventTuple), [
        (WorkspaceChangeEventType.move, 'new.dart', 'old.dart'),
      ]);
    });

    test('scopes remove suppression to one matching event', () async {
      final delivered = api.changeEvents.take(3).toList();
      api.addMoveIntention('old.dart', 'new.dart');
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
      api.changeEvents.listen(secondListenerEvents.add);
      final delivered = api.changeEvents.first;

      stream.emitAdd('file.dart');
      await delivered;

      expect(events, hasLength(1));
      expect(secondListenerEvents, hasLength(1));
    });

    test('ready waits for the SDK watcher readiness signal', () async {
      final sourceReady = Completer<void>();
      api = FakeWorkspaceEventsApi(
        rawFileChanges: stream.stream,
        fileChangesReady: sourceReady.future,
      );

      var completed = false;
      final start = api.changeEventsReady.then((_) => completed = true);
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
