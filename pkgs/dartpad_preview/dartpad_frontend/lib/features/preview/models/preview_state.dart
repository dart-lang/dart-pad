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

extension PreviewStateCapabilities on PreviewState {
  bool get isTransitioning => switch (this) {
    PreviewStarting() || PreviewRestarting() || PreviewHotReloading() || PreviewStopping() => true,
    PreviewInitial() || PreviewRunning() || PreviewDartReady() || PreviewCompileError() => false,
  };

  bool get allowsStart => switch (this) {
    PreviewInitial() || PreviewDartReady() || PreviewCompileError() => true,
    PreviewStarting() || PreviewRunning() || PreviewRestarting() || PreviewHotReloading() || PreviewStopping() => false,
  };

  bool get allowsRestart => switch (this) {
    PreviewRunning() => true,
    PreviewInitial() ||
    PreviewStarting() ||
    PreviewDartReady() ||
    PreviewRestarting() ||
    PreviewHotReloading() ||
    PreviewStopping() ||
    PreviewCompileError() => false,
  };

  bool get allowsStop => switch (this) {
    PreviewRunning() || PreviewStarting() || PreviewRestarting() || PreviewHotReloading() => true,
    PreviewStopping() || PreviewDartReady() || PreviewInitial() || PreviewCompileError() => false,
  };

  bool get hasActivePreview => switch (this) {
    PreviewRunning() || PreviewRestarting() || PreviewHotReloading() => true,
    PreviewInitial() || PreviewStarting() || PreviewDartReady() || PreviewStopping() || PreviewCompileError() => false,
  };
}

/// The initial state when no preview has started yet.
final class PreviewInitial extends PreviewState {}

/// Base class for states that represent an active preview session executing a
/// specific [entrypoint].
sealed class _ActivePreviewState extends PreviewState {
  _ActivePreviewState(this.entrypoint);

  @override
  final String entrypoint;
}

/// State representing a fresh startup compilation and execution lifecycle.
final class PreviewStarting extends _ActivePreviewState {
  PreviewStarting(super.entrypoint);
}

/// State representing an active running application preview.
final class PreviewRunning extends _ActivePreviewState {
  PreviewRunning(super.entrypoint);
}

/// State after successfully launching a Dart console program.
///
/// The UI is ready for another run; async main and timers may still be running.
final class PreviewDartReady extends _ActivePreviewState {
  PreviewDartReady(super.entrypoint);
}

/// State representing an application restart after recompiling current sources.
final class PreviewRestarting extends _ActivePreviewState {
  PreviewRestarting(super.entrypoint);
}

/// State representing a preview sandbox hot-reloading code modifications.
final class PreviewHotReloading extends _ActivePreviewState {
  PreviewHotReloading(super.entrypoint);
}

/// State representing an active stop/shutdown execution process.
final class PreviewStopping extends PreviewState {}

/// The user action that initiated a preview launch lifecycle.
enum PreviewLaunchAction {
  /// A fresh startup launch of the preview.
  start,

  /// An application restart following code modifications or user action.
  restart,
}

/// State representing a compiler or runtime failure while compiling the
/// [entrypoint].
final class PreviewCompileError extends PreviewState {
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
