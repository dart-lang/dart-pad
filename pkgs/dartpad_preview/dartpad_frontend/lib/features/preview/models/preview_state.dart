// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../shared/task_status.dart';

/// Base sealed class representing the current visual and execution state of
/// the preview.
sealed class PreviewState {
  /// The entrypoint path associated with this state, if any; otherwise `null`.
  String? get entrypoint => null;
}

/// The initial state when no preview has started yet.
class PreviewInitial extends PreviewState {}

/// Base class for states that represent an active preview session executing a
/// specific [entrypoint].
class _ActivePreviewState extends PreviewState {
  _ActivePreviewState(this.entrypoint);

  @override
  final String entrypoint;
}

/// State representing a fresh startup compilation and execution lifecycle.
class PreviewStarting extends _ActivePreviewState {
  PreviewStarting(super.entrypoint);
}

/// State representing an active running application preview.
class PreviewRunning extends _ActivePreviewState {
  PreviewRunning(super.entrypoint);
}

/// State representing an application restart after recompiling current sources.
class PreviewRestarting extends _ActivePreviewState {
  PreviewRestarting(super.entrypoint);
}

/// State representing a compiler session hot-reloading code modifications.
class PreviewHotReloading extends _ActivePreviewState {
  PreviewHotReloading(super.entrypoint);
}

/// State representing an active stop/shutdown execution process.
class PreviewStopping extends PreviewState {}

/// The user action that initiated a preview launch lifecycle.
enum PreviewLaunchAction { start, restart }

/// State representing a compiler or runtime failure while compiling the
/// [entrypoint].
class PreviewCompileError extends PreviewState {
  PreviewCompileError(
    this.entrypoint,
    this.message, {
    required this.action,
    required this.failedTask,
  });

  @override
  final String entrypoint;

  /// The error message describing the failure.
  final String message;

  /// Whether the failed launch was a fresh start or a restart.
  final PreviewLaunchAction action;

  /// The typed task phase that failed.
  final TaskKind failedTask;
}
