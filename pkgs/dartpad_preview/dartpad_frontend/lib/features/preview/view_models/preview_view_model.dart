// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../bottom_panel/models/console_entry.dart';
import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';
import '../../shared/log_source.dart';
import '../../shared/run_availability.dart';
import '../../shared/task_status.dart';
import '../../workspace/data/workspace_repository.dart';
import '../models/preview_sandbox.dart';
import '../models/preview_state.dart';
import '../models/run_mode.dart';

/// Coordinates UI state and synchronization around the SDK-owned compiler/runtime.
interface class PreviewViewModel extends ChangeNotifier implements RunAvailability {
  /// Starts with an [initialMode] for the SDK and entrypoint.
  ///
  /// A null [modeOverride] allows inference on subsequent runs; a value keeps
  /// the explicit query mode in effect.
  PreviewViewModel({
    required WorkspaceRepository workspaceRepository,
    required AppEventBus eventBus,
    required RunMode initialMode,
    Future<PreviewSandbox> Function(web.Element, {required Uri assetBaseUrl})? createSandbox,
    Future<void> Function()? onSaveAll,
    String? initialEntrypoint,
    RunMode? modeOverride,
  }) : this._(workspaceRepository, eventBus, createSandbox, onSaveAll, initialEntrypoint, modeOverride, initialMode);

  PreviewViewModel._(
    this._workspaceRepository,
    this._eventBus,
    this._createSandbox,
    this._onSaveAll,
    this._entrypoint,
    this._modeOverride,
    this._previewMode,
  );

  String? _entrypoint;
  String? get entrypoint => _entrypoint;
  final RunMode? _modeOverride;

  Future<void> runCurrent() async {
    final path = _entrypoint;
    if (path != null) {
      await runCode(path);
    }
  }

  final WorkspaceRepository _workspaceRepository;
  final AppEventBus _eventBus;
  final Future<PreviewSandbox> Function(web.Element, {required Uri assetBaseUrl})? _createSandbox;
  final Future<void> Function()? _onSaveAll;

  final web.Element _container = web.document.createElement('div')..className = 'preview';

  /// The DOM element in which the preview sandbox is mounted.
  web.Element get containerElement => _container;

  PreviewState _state = PreviewInitial();

  /// The current preview lifecycle state.
  PreviewState get state => _state;

  RunMode _previewMode;

  /// The mode selected for the current or most recent preview launch.
  RunMode get previewMode => _previewMode;

  final List<ConsoleEntry> _appLogs = [];

  /// Console entries emitted by the running Dart application.
  List<ConsoleEntry> get appLogs => List.unmodifiable(_appLogs);
  PreviewSandbox? _sandbox;
  String? _runningPath;
  RunMode? _runningMode;
  final List<StreamSubscription<String>> _subscriptions = [];
  bool _disposed = false;
  int _operationId = 0;

  bool get _launchBlocked => _disposed || _workspaceRepository.taskStatus.hasBlockingPreviewTask;

  /// Whether an explicitly supplied entrypoint can be launched now.
  @override
  bool get canRun => !_launchBlocked && (_state.allowsStart || _state.allowsRestart);

  /// Whether a new preview launch can be started.
  bool get canStart => _entrypoint != null && !_launchBlocked && _state.allowsStart;

  /// Whether the running preview can be restarted.
  bool get canRestart => !_launchBlocked && _state.allowsRestart;

  /// Whether the running Flutter preview can be hot reloaded.
  bool get canHotReload => _previewMode == RunMode.flutter && canRestart;

  /// Whether the current preview operation or sandbox can be stopped.
  bool get canStop => !_disposed && _state.allowsStop && (_state.isTransitioning || _sandbox != null);

  /// Whether a Flutter preview is running, restarting, or hot reloading.
  bool get isRunning => _state.hasActivePreview;
  bool _current(int id) => !_disposed && id == _operationId;

  Future<void> _saveAndFlush() async {
    await _onSaveAll?.call();
    await _workspaceRepository.flush();
  }

  /// Runs [entrypoint] in the requested [mode].
  ///
  /// Without an override, infer the mode from the SDK and the entrypoint's
  /// location relative to its nearest package root.
  Future<void> runCode(String entrypoint, {RunMode? mode}) async {
    if (!canRun) {
      return;
    }
    _entrypoint = entrypoint;
    final id = ++_operationId;
    final restart = canRestart;
    final action = restart ? PreviewLaunchAction.restart : PreviewLaunchAction.start;
    final kind = restart ? TaskKind.restartingPreview : TaskKind.startingPreview;
    final task = _workspaceRepository.taskStatus.startTask(kind, blocksPreview: true);
    _state = restart ? PreviewRestarting(entrypoint) : PreviewStarting(entrypoint);
    _appLogs.clear();
    notifyListeners();
    var failedTask = kind;
    try {
      await _saveAndFlush();
      if (!_current(id)) {
        return;
      }
      final runMode = mode ?? _modeOverride ?? await _workspaceRepository.runModeFor(entrypoint);
      if (!_current(id)) {
        return;
      }
      if (runMode == RunMode.flutter && !_workspaceRepository.sdk.isFlutter) {
        throw const FormatException('Flutter mode requires a Flutter SDK.');
      }
      // Set routing before run(), which may emit output before its future completes.
      _previewMode = runMode;
      final reuse = _sandbox != null && _runningPath == entrypoint && _runningMode == runMode;
      if (!reuse) {
        await _closeSandbox();
        if (!_current(id)) {
          return;
        }
        final PreviewSandbox sandbox;
        final createSandbox = _createSandbox;
        if (createSandbox != null) {
          sandbox = await createSandbox(_container, assetBaseUrl: _workspaceRepository.assetBaseUrl);
        } else {
          final workspace = await _workspaceRepository.readyWorkspace;
          if (!_current(id)) {
            return;
          }
          sandbox = await IframePreviewSandbox.create(
            _container,
            assetBaseUrl: _workspaceRepository.assetBaseUrl,
            workspace: workspace,
          );
        }
        if (!_current(id)) {
          await sandbox.close();
          return;
        }
        _sandbox = sandbox;
        _attachOutput(sandbox);
      }
      final sandbox = _sandbox!;
      if (!sandbox.modes.contains(runMode.mode)) {
        throw FormatException('This SDK does not support ${runMode.mode} mode.');
      }
      _eventBus.dispatch(
        LogEvent('Compiling and ${reuse ? 'restarting' : 'running'} $entrypoint (${runMode.mode})...'),
      );
      failedTask = TaskKind.compilingApplication;
      final result = await _workspaceRepository.taskStatus.runTask(
        TaskKind.compilingApplication,
        () => reuse ? sandbox.hotRestart() : sandbox.run(entrypoint, mode: runMode.mode),
        blocksPreview: true,
      );
      if (!_current(id)) {
        return;
      }
      _eventBus.dispatch(LogEvent(result.log));
      _runningPath = entrypoint;
      _runningMode = runMode;
      _state = switch (runMode) {
        RunMode.flutter => PreviewRunning(entrypoint),
        RunMode.console => PreviewDartReady(entrypoint),
      };
      task.succeed();
    } catch (error, stack) {
      if (!_current(id)) {
        return;
      }
      _eventBus.dispatch(LogEvent('Run failed', level: Level.SEVERE, error: error, stackTrace: stack));
      _state = PreviewCompileError(
        entrypoint,
        error is DartPadException ? error.message : error.toString(),
        action: action,
        failedTask: failedTask,
      );
      try {
        await _closeSandbox();
      } catch (cleanupError, cleanupStack) {
        _eventBus.dispatch(
          LogEvent(
            'Preview cleanup failed',
            level: Level.SEVERE,
            error: cleanupError,
            stackTrace: cleanupStack,
          ),
        );
      } finally {
        task.fail();
      }
    } finally {
      if (!_current(id)) {
        task.cancel();
      }
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Recompiles and restarts the currently running entrypoint.
  Future<void> restartCode() async {
    if (!canRestart) {
      return;
    }
    final entrypoint = _runningPath;
    final mode = _runningMode;
    if (entrypoint == null || mode == null) {
      return;
    }
    await runCode(entrypoint, mode: mode);
  }

  /// Hot reloads changes into the running Flutter preview.
  Future<void> hotReloadCode() async {
    if (!canHotReload || _sandbox == null) {
      return;
    }
    final id = ++_operationId;
    final entrypoint = _runningPath!;
    final sandbox = _sandbox!;
    final task = _workspaceRepository.taskStatus.startTask(TaskKind.hotReload, blocksPreview: true);
    _state = PreviewHotReloading(entrypoint);
    notifyListeners();
    try {
      await _saveAndFlush();
      if (!_current(id)) {
        return;
      }
      final result = await _workspaceRepository.taskStatus.runTask(
        TaskKind.compilingChanges,
        sandbox.hotReload,
        blocksPreview: true,
      );
      if (!_current(id)) {
        return;
      }
      _eventBus.dispatch(LogEvent(result.log));
      task.succeed();
    } catch (error, stack) {
      if (!_current(id)) {
        return;
      }
      _eventBus.dispatch(
        LogEvent(
          'Hot reload failed',
          level: error is HotReloadRejectedException ? Level.WARNING : Level.SEVERE,
          error: error,
          stackTrace: stack,
        ),
      );
      task.fail();
    } finally {
      if (_current(id)) {
        _state = PreviewRunning(entrypoint);
        notifyListeners();
      } else {
        task.cancel();
      }
    }
  }

  Future<void>? _stopping;

  /// Stops the current preview and completes after its resources are closed.
  Future<void> stopCode() {
    if (_disposed) {
      return Future.value();
    }
    final stopping = _stopping;
    if (stopping != null) {
      return stopping;
    }

    final completer = Completer<void>();
    _stopping = completer.future;
    unawaited(
      _stopCodeOnce().then(completer.complete, onError: completer.completeError).whenComplete(() {
        _stopping = null;
      }),
    );
    return completer.future;
  }

  Future<void> _stopCodeOnce() async {
    final id = ++_operationId;
    final task = _workspaceRepository.taskStatus.startTask(TaskKind.stoppingPreview, blocksPreview: true);
    _state = PreviewStopping();
    notifyListeners();
    try {
      await _closeSandbox();
      if (!_current(id)) {
        task.cancel();
        return;
      }
      _state = PreviewInitial();
      task.succeed();
    } catch (error, stack) {
      if (!_current(id)) {
        task.cancel();
        return;
      }
      _eventBus.dispatch(LogEvent('Stop failed', level: Level.SEVERE, error: error, stackTrace: stack));
      _state = PreviewInitial();
      task.fail();
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _attachOutput(PreviewSandbox sandbox) {
    void output(String message, Level level) {
      if (_disposed || !identical(_sandbox, sandbox)) {
        return;
      }
      final isRuntimeStatus =
          message.startsWith('Starting application from') || message.startsWith('Hot restarting application from');
      if (_previewMode == RunMode.flutter || isRuntimeStatus) {
        _eventBus.dispatch(
          LogEvent(
            message,
            level: level,
            source: LogSource.app,
            isApplicationOutput: !isRuntimeStatus,
          ),
        );
      } else {
        _appLogs.add(
          ConsoleEntry(
            message: message,
            level: level,
            source: LogSource.app,
            isApplicationOutput: true,
          ),
        );
        notifyListeners();
      }
    }

    void streamError(String streamName, Object error, StackTrace stackTrace) {
      output('$streamName stream failed: $error', Level.SEVERE);
    }

    _subscriptions.addAll([
      sandbox.console.listen(
        (message) => output(message, Level.INFO),
        onError: (Object error, StackTrace stackTrace) => streamError('Console', error, stackTrace),
      ),
      sandbox.errors.listen(
        (message) => output(message, Level.SEVERE),
        onError: (Object error, StackTrace stackTrace) => streamError('Error', error, stackTrace),
      ),
      sandbox.unhandledRejections.listen(
        (message) => output(message, Level.SEVERE),
        onError: (Object error, StackTrace stackTrace) => streamError('Unhandled rejection', error, stackTrace),
      ),
    ]);
  }

  Future<void>? _closingSandbox;

  Future<void> _closeSandbox() => _closingSandbox ??= _closeSandboxOnce();

  Future<void> _closeSandboxOnce() async {
    try {
      final sandbox = _sandbox;
      _sandbox = null;
      _runningPath = null;
      _runningMode = null;
      final subscriptions = List.of(_subscriptions);
      _subscriptions.clear();
      try {
        for (final subscription in subscriptions) {
          try {
            await subscription.cancel();
          } catch (error, stack) {
            _eventBus.dispatch(
              LogEvent(
                'Preview output subscription cleanup failed',
                level: Level.WARNING,
                error: error,
                stackTrace: stack,
              ),
            );
          }
        }
      } finally {
        await sandbox?.close();
      }
    } finally {
      _closingSandbox = null;
    }
  }

  Future<void>? _cleanup;

  /// Completes when resource cleanup triggered by [dispose] has finished.
  Future<void> get closed => _cleanup ?? Future.value();

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _operationId++;
    _cleanup = _closeSandbox();
    unawaited(_cleanup);
    super.dispose();
  }
}
