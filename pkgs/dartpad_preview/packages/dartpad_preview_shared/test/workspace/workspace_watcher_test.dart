import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_preview_shared/workspace/workspace_watcher.dart';
import 'package:test/test.dart';

class FakeWorkspace implements Workspace {
  final StreamController<WorkspaceEvent> _changes = StreamController<WorkspaceEvent>.broadcast();

  @override
  Stream<WorkspaceEvent> get fileSystemChanges => _changes.stream;

  @override
  Uri get workspaceFolder => Uri.parse('file:///workspace/');

  @override
  int get id => 0;

  void emit(WorkspaceEventType type, String path) {
    _changes.add(WorkspaceEvent.fromMap({'type': type.name, 'path': path}));
  }

  Future<void> close() => _changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RenameCache', () {
    test('tracks, overwrites, and consumes move intentions independently', () {
      final workspace = FakeWorkspace();
      addTearDown(workspace.close);

      workspace
        ..addMoveIntention('a.dart', 'target.dart')
        ..addMoveIntention('replacement.dart', 'target.dart')
        ..addMoveIntention('x.dart', 'y.dart');

      expect(workspace.pendingMoves, {
        'target.dart': 'replacement.dart',
        'y.dart': 'x.dart',
      });
      expect(workspace.removeMoveIntention('target.dart'), 'replacement.dart');
      expect(workspace.removeMoveIntention('target.dart'), isNull);
      expect(workspace.removeMoveIntention('y.dart'), 'x.dart');
    });

    test('keeps move intentions isolated per workspace', () {
      final first = FakeWorkspace();
      final second = FakeWorkspace();
      addTearDown(first.close);
      addTearDown(second.close);

      first.addMoveIntention('a.dart', 'b.dart');

      expect(second.removeMoveIntention('b.dart'), isNull);
      expect(first.removeMoveIntention('b.dart'), 'a.dart');
    });
  });

  group('WorkspaceWatcher', () {
    late FakeWorkspace workspace;
    late WorkspaceWatcher watcher;
    late List<WorkspaceChangeEvent> events;

    setUp(() {
      workspace = FakeWorkspace();
      watcher = WorkspaceWatcher(workspace: workspace)..watchFileSystem();
      events = [];
      watcher.events.listen(events.add);
    });

    tearDown(() => workspace.close());

    test('forwards raw add, remove, and modify events', () async {
      final delivered = watcher.events.take(3).toList();
      workspace
        ..emit(WorkspaceEventType.add, 'added.dart')
        ..emit(WorkspaceEventType.remove, 'removed.dart')
        ..emit(WorkspaceEventType.modify, 'modified.dart');
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
      workspace
        ..addMoveIntention('old.dart', 'new.dart')
        ..emit(WorkspaceEventType.add, 'new.dart')
        ..emit(WorkspaceEventType.remove, 'old.dart');
      await delivered;

      expect(events.map(_eventTuple), [
        (WorkspaceChangeEventType.move, 'new.dart', 'old.dart'),
      ]);
    });

    test('scopes remove suppression to one matching event', () async {
      final delivered = watcher.events.take(3).toList();
      workspace
        ..addMoveIntention('old.dart', 'new.dart')
        ..emit(WorkspaceEventType.add, 'new.dart')
        ..emit(WorkspaceEventType.remove, 'unrelated.dart')
        ..emit(WorkspaceEventType.remove, 'old.dart')
        ..emit(WorkspaceEventType.remove, 'old.dart');
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

      workspace.emit(WorkspaceEventType.add, 'file.dart');
      await delivered;

      expect(events, hasLength(1));
      expect(secondListenerEvents, hasLength(1));
    });
  });
}

(WorkspaceChangeEventType, String, String?) _eventTuple(
  WorkspaceChangeEvent event,
) => (event.type, event.path, event.oldPath);
