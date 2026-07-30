// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:meta/meta.dart';

import 'workspace_api.dart';

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

/// A mixin that provides event reconciliation logic for [WorkspaceResourceApi] implementations.
///
/// It listens to the raw [FileChangeEvent] stream supplied by [rawFileChanges] and merges
/// addition and removal sequences into unified [WorkspaceChangeEventType.move] events
/// when matched against registered pending moves.
abstract mixin class WorkspaceResourceEventsMixin implements WorkspaceResourceApi {
  /// Tracks old paths of moved folders/files that need to be ignored when
  /// their raw `remove` event subsequently arrives from the filesystem watcher.
  final Set<String> _pendingRemovesToDrop = {};

  /// The map of pending moves, mapping new target path to original source path.
  final Map<String, String> _pendingMoves = {};

  /// Exposes the map of pending moves for testing purposes.
  @visibleForTesting
  Map<String, String> get pendingMoves => _pendingMoves;

  @override
  void addMoveIntention(String oldPath, String newPath) {
    _pendingMoves[newPath] = oldPath;
  }

  String? _removeMoveIntention(String newPath) {
    return _pendingMoves.remove(newPath);
  }

  /// The raw event stream that subclasses must provide.
  Stream<FileChangeEvent> get rawFileChanges;

  late final Stream<WorkspaceChangeEvent> _reconciledFileChanges = _reconcile(rawFileChanges);

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => _reconciledFileChanges;

  /// Reconciles the raw file events (`add`, `remove`, `modify`) using the pending move cache.
  ///
  /// If a raw `add` event occurs at a path that matches a registered pending move:
  /// - A unified [WorkspaceChangeEventType.move] event is emitted immediately.
  /// - The original source path is added to [_pendingRemovesToDrop] so that
  ///   when the corresponding raw `remove` event eventually fires, it is ignored
  ///   rather than falsely reporting a deletion to the UI.
  Stream<WorkspaceChangeEvent> _reconcile(Stream<FileChangeEvent> rawChanges) {
    late StreamController<WorkspaceChangeEvent> controller;
    StreamSubscription<FileChangeEvent>? subscription;

    controller = StreamController<WorkspaceChangeEvent>.broadcast(
      onListen: () {
        subscription = rawChanges.listen(
          (e) {
            final path = e.uri.path;
            if (e is FileAddedEvent) {
              final oldPath = _removeMoveIntention(path);
              if (oldPath != null) {
                _pendingRemovesToDrop.add(oldPath);
                controller.add(
                  WorkspaceChangeEvent(
                    type: WorkspaceChangeEventType.move,
                    path: path,
                    oldPath: oldPath,
                  ),
                );
              } else {
                controller.add(
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
              controller.add(
                WorkspaceChangeEvent(
                  type: WorkspaceChangeEventType.remove,
                  path: path,
                ),
              );
            } else if (e is FileModifiedEvent) {
              controller.add(
                WorkspaceChangeEvent(
                  type: WorkspaceChangeEventType.modify,
                  path: path,
                ),
              );
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
