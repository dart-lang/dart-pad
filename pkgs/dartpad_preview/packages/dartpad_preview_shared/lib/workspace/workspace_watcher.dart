import 'dart:async';

import 'package:dartpad/dartpad.dart';

/// Watches the underlying [Workspace] for filesystem events and emits
/// consolidated [WorkspaceChangeEvent]s that reconcile raw add/remove events
/// into higher-level move events using the [RenameCache].
class WorkspaceWatcher {
  /// Creates a [WorkspaceWatcher] for the given [workspace].
  WorkspaceWatcher({required this.workspace});

  /// The workspace whose filesystem events are being watched.
  final Workspace workspace;

  final StreamController<WorkspaceChangeEvent> _eventsController = StreamController<WorkspaceChangeEvent>.broadcast();

  /// A stream of high-level workspace events (adds, removes, modifies, moves)
  /// processed and consolidated for UI consumption.
  Stream<WorkspaceChangeEvent> get events => _eventsController.stream;

  /// Tracks old paths of moved folders/files that need to be ignored when
  /// their raw `remove` event subsequently arrives from the filesystem watcher.
  final Set<String> _pendingRemovesToDrop = {};

  /// Starts watching filesystem events from the underlying workspace and
  /// processes them into consolidated events.
  ///
  /// Since the workspace only broadcasts raw events (`add`, `remove`, `modify`),
  /// this method reconciles them using the workspace's pending move cache.
  ///
  /// If a raw `add` event occurs at a path that matches a registered pending move:
  /// - A unified [WorkspaceChangeEventType.move] event is emitted immediately.
  /// - The original source path is added to [_pendingRemovesToDrop] so that
  ///   when the corresponding raw `remove` event eventually fires, it is ignored
  ///   rather than falsely reporting a deletion to the UI.
  Future<void> watchFileSystem() async {
    workspace.fileSystemChanges.listen((e) {
      final path = e.path;
      if (e.type == WorkspaceEventType.add) {
        final oldPath = workspace.removeMoveIntention(path);
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
      } else if (e.type == WorkspaceEventType.remove) {
        if (_pendingRemovesToDrop.remove(path)) {
          return;
        }
        _eventsController.add(
          WorkspaceChangeEvent(
            type: WorkspaceChangeEventType.remove,
            path: path,
          ),
        );
      } else if (e.type == WorkspaceEventType.modify) {
        _eventsController.add(
          WorkspaceChangeEvent(
            type: WorkspaceChangeEventType.modify,
            path: path,
          ),
        );
      }
    });
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

/// Internal cache storing move/rename intentions.
/// Maps the target path (newPath) to the source path (oldPath).
final Expando<Map<String, String>> _workspaceMoveCache = Expando();

/// Extension to support tracking pending rename/move operations on a [Workspace].
///
/// Because moving folders/files in the underlying workspace occurs via separate
/// file writes and deletes, we cache "intentions" (the old path to new path mapping)
/// to reconcile the resulting raw filesystem events (e.g. `add` and `remove` events)
/// into unified `move` events.
extension RenameCache on Workspace {
  /// The map of pending moves, mapping new target path to original source path.
  Map<String, String> get pendingMoves => _workspaceMoveCache[this] ??= {};

  /// Registers an intention to move/rename a resource from [oldPath] to [newPath].
  void addMoveIntention(String oldPath, String newPath) {
    pendingMoves[newPath] = oldPath;
  }

  /// Removes and returns the original source path for a pending move to [newPath],
  /// if one was registered.
  String? removeMoveIntention(String newPath) {
    return pendingMoves.remove(newPath);
  }
}
