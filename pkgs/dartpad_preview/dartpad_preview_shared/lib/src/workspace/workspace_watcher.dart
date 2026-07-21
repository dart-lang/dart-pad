// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

// TODO: Use package:dartpad/dartpad.dart once it exports the file change event which should be fixed in Version 0.0.4 (currently at 0.0.3)
// types returned by WorkspaceWatcher.changes.
// ignore: implementation_imports
import 'package:dartpad/src/worker_client.dart'
    show FileAddedEvent, FileChangeEvent, FileModifiedEvent, FileRemovedEvent;

/// Watches a filesystem event stream and emits
/// consolidated [WorkspaceChangeEvent]s that reconcile raw add/remove events
/// into higher-level move events.
class WorkspaceChangeWatcher {
  /// Creates a [WorkspaceChangeWatcher] that listens to [fileChanges].
  WorkspaceChangeWatcher({required this.fileChanges});

  /// The stream of raw filesystem events.
  final Stream<FileChangeEvent> fileChanges;

  final StreamController<WorkspaceChangeEvent> _eventsController = StreamController<WorkspaceChangeEvent>.broadcast();
  StreamSubscription<FileChangeEvent>? _fileChangesSubscription;

  /// A stream of high-level workspace events (adds, removes, modifies, moves)
  /// processed and consolidated for UI consumption.
  Stream<WorkspaceChangeEvent> get events => _eventsController.stream;

  /// Tracks old paths of moved folders/files that need to be ignored when
  /// their raw `remove` event subsequently arrives from the filesystem watcher.
  final Set<String> _pendingRemovesToDrop = {};

  /// The map of pending moves, mapping new target path to original source path.
  final Map<String, String> pendingMoves = {};

  /// Registers an intention to move/rename a resource from [oldPath] to [newPath].
  void addMoveIntention(String oldPath, String newPath) {
    pendingMoves[newPath] = oldPath;
  }

  /// Removes and returns the original source path for a pending move to [newPath],
  /// if one was registered.
  String? removeMoveIntention(String newPath) {
    return pendingMoves.remove(newPath);
  }

  /// Starts watching filesystem events and processes them into consolidated events.
  ///
  /// Since the stream only broadcasts raw events (`add`, `remove`, `modify`),
  /// this method reconciles them using the pending move cache.
  ///
  /// If a raw `add` event occurs at a path that matches a registered pending move:
  /// - A unified [WorkspaceChangeEventType.move] event is emitted immediately.
  /// - The original source path is added to [_pendingRemovesToDrop] so that
  ///   when the corresponding raw `remove` event eventually fires, it is ignored
  ///   rather than falsely reporting a deletion to the UI.
  void watchFileSystem() {
    if (_fileChangesSubscription != null) {
      return;
    }
    _fileChangesSubscription = fileChanges.listen((e) {
      final path = e.uri.path;
      if (e is FileAddedEvent) {
        final oldPath = removeMoveIntention(path);
        if (oldPath != null) {
          _pendingRemovesToDrop.add(oldPath);
          _eventsController.add(
            WorkspaceChangeEvent(
              type: WorkspaceChangeEventType.move,
              path: path,
              oldPath: oldPath,
            ),
          );
        } else {
          _eventsController.add(
            WorkspaceChangeEvent(
              type: WorkspaceChangeEventType.add,
              path: path,
            ),
          );
        }
      } else if (e is FileRemovedEvent) {
        if (_pendingRemovesToDrop.remove(path)) {
          return;
        }
        _eventsController.add(
          WorkspaceChangeEvent(
            type: WorkspaceChangeEventType.remove,
            path: path,
          ),
        );
      } else if (e is FileModifiedEvent) {
        _eventsController.add(
          WorkspaceChangeEvent(
            type: WorkspaceChangeEventType.modify,
            path: path,
          ),
        );
      }
    });
  }

  /// Stops watching filesystem events and closes the processed event stream.
  Future<void> dispose() async {
    await _fileChangesSubscription?.cancel();
    _fileChangesSubscription = null;
    await _eventsController.close();
  }
}

/// The type of file change event propagated to the UI.
enum WorkspaceChangeEventType {
  /// A new file or folder has been added.
  add,

  /// A file or folder has been removed.
  remove,

  /// A file's content has been modified.
  modify,

  /// A file or folder has been renamed or moved.
  move,
}

/// An event describing a change in the workspace filesystem.
class WorkspaceChangeEvent {
  WorkspaceChangeEvent({
    required this.type,
    required this.path,
    this.oldPath,
  });

  /// The type of change that occurred.
  final WorkspaceChangeEventType type;

  /// The path to the affected resource.
  final String path;

  /// The original path if the event type is [WorkspaceChangeEventType.move].
  final String? oldPath;
}
