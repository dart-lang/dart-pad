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
import '../../shared/events/sandbox_event.dart';
import '../../workspace/data/workspace_repository.dart';
import '../models/compiler_session.dart';
import '../models/preview_sandbox.dart';
import '../models/preview_state.dart';

/// View model managing compiler sessions, iframe sandbox state, console
/// stream bindings, and reactive state updates for the application
/// preview panel.
class PreviewViewModel extends ChangeNotifier {
  PreviewViewModel({
    required this.workspaceRepository,
    required this.eventBus,
    this.createSandbox = _createRealSandbox,
  }) {
    eventBus.on<RequestSandboxEvent>().listen((event) {
      event.complete(SandboxChangedEvent(_sandbox, isFlutterApp: _isFlutter));
    });
  }

  /// Repository for working with file systems, compiler sessions, and
  /// package properties.
  final WorkspaceRepository workspaceRepository;

  /// Global event bus for logging and UI command dispatching.
  final AppEventBus eventBus;

  /// Creates a sandboxed environment for execution.
  final Future<PreviewSandbox> Function(web.Node, {required Uri assetBaseUrl}) createSandbox;

  static Future<PreviewSandbox> _createRealSandbox(web.Node container, {required Uri assetBaseUrl}) async {
    final sandbox = await Sandbox.createIFrame(container, assetBaseUrl: assetBaseUrl);
    return RealPreviewSandbox(sandbox);
  }

  PreviewSandbox? _sandbox;
  PreviewSandbox? get sandbox => _sandbox;
  CompilerSession? _hotReloadCompiler;

  bool _disposed = false;
  StreamSubscription<dynamic>? _sandboxConsoleSubscription;
  StreamSubscription<dynamic>? _sandboxErrorSubscription;
  StreamSubscription<dynamic>? _sandboxRejectionSubscription;

  /// The root HTML container element where the preview iframe sandbox is hosted.
  web.Element get containerElement => _container;
  final web.Element _container = web.document.createElement('div')..className = 'preview';

  /// The current state of compiling, validation, running, or stopping the preview.
  PreviewState get state => _state;
  PreviewState _state = PreviewInitial();

  /// Whether the running app uses Flutter.
  bool get isFlutter => _isFlutter;
  bool _isFlutter = true;

  /// Logs collected from the running application (used in pure Dart mode).
  List<ConsoleEntry> get appLogs => List.unmodifiable(_appLogs);
  final List<ConsoleEntry> _appLogs = [];

  /// Whether the compiler or execution setup can be started.
  bool get canStart => !_busy && (_state is PreviewInitial || _state is PreviewCompileError);

  /// Whether the running preview can be restarted.
  bool get canRestart => !_busy && _state is PreviewRunning;

  /// Whether the running preview can accept a hot reload.
  bool get canHotReload => !_busy && _state is PreviewRunning;

  /// Whether the preview run process can be stopped.
  bool get canStop => _state is! PreviewStopping && (_busy || _sandbox != null);

  /// Whether the application preview is currently running or executing restarts/reloads.
  bool get isRunning => _state is PreviewRunning || state is PreviewRestarting || state is PreviewHotReloading;

  bool get _busy =>
      _state is PreviewStarting ||
      _state is PreviewRestarting ||
      _state is PreviewHotReloading ||
      _state is PreviewStopping;

  // Monotonically increasing token for preview operations.
  //
  // Async start/hot-reload steps must still own the current token before mutating state,
  // so stale work cannot revive the preview after a stop or newer run.
  int _operationId = 0;

  String? _lastCompiledCode;

  /// Starts the preview for [entrypoint].
  ///
  /// By default this creates a fresh compiler session, compiles the current
  /// sources, loads the resulting module into a new sandbox, and runs the app.
  ///
  /// If [skipRecompilation] is `true`, this skips recompilation and reuses the
  /// last successfully compiled module from [_lastCompiledCode] instead. This is
  /// used for restart semantics where we want to recreate the sandbox and reset
  /// runtime state without recompiling unchanged code.
  ///
  /// If no cached artifact is available yet, the code is compiled even when
  /// [skipRecompilation] is `true`.
  Future<void> runCode(String entrypoint, {bool skipRecompilation = false}) async {
    if (_busy) {
      return;
    }

    final operationId = _beginOperation();

    _appLogs.clear();

    final compileNeeded = !skipRecompilation || _lastCompiledCode == null;
    eventBus.dispatch(LogEvent('Run $entrypoint'));
    if (compileNeeded) {
      eventBus.dispatch(const LogEvent('Starting compiler...'));
    }

    if (_state is PreviewRunning ||
        _state is PreviewRestarting ||
        _state is PreviewHotReloading ||
        _state is PreviewStopping) {
      _state = PreviewRestarting(entrypoint);
    } else {
      _state = PreviewStarting(entrypoint);
    }
    notifyListeners();

    try {
      final String codeToLoad;

      if (compileNeeded) {
        final previousCompiler = _hotReloadCompiler;
        if (previousCompiler != null) {
          eventBus.dispatch(const LogEvent('Closing previous compiler session...'));
          _hotReloadCompiler = null;
          await previousCompiler.close();
          if (!_isCurrentOperation(operationId)) {
            return;
          }
        }

        eventBus.dispatch(const LogEvent('Creating hot reload compiler...'));
        final compiler = await workspaceRepository.startHotReloadCompiler(
          Uri.parse(entrypoint),
        );
        if (!_isCurrentOperation(operationId)) {
          await compiler.close();
          return;
        }
        _hotReloadCompiler = compiler;

        eventBus.dispatch(const LogEvent('Compiling application...'));
        final result = await compiler.compile();
        if (!_isCurrentOperation(operationId)) {
          return;
        }
        eventBus.dispatch(LogEvent(result.log ?? ''));
        eventBus.dispatch(const LogEvent('Compilation succeeded.'));
        _lastCompiledCode = result.code;
        codeToLoad = result.code!;
      } else {
        codeToLoad = _lastCompiledCode!;
      }

      final assetBaseUrl = Uri.parse(web.document.baseURI).resolve('dartpad/flutter/');

      final previousSandbox = _sandbox;
      if (previousSandbox != null) {
        eventBus.dispatch(const LogEvent('Disposing previous preview sandbox...'));
        await _disposeCurrentSandbox(previousSandbox);
        if (!_isCurrentOperation(operationId)) {
          return;
        }
      }

      final libraryUri = await workspaceRepository.convertToPackageUri(entrypoint);
      final isFlutter = await workspaceRepository.hasFlutterDependency(entrypoint);
      _isFlutter = isFlutter;

      eventBus.dispatch(const LogEvent('Creating preview sandbox...'));
      final sandbox = await createSandbox(
        _container,
        assetBaseUrl: assetBaseUrl,
      );
      if (!_isCurrentOperation(operationId)) {
        sandbox.dispose();
        return;
      }
      _sandbox = sandbox;
      await _attachSandboxConsole(sandbox);
      if (!_isCurrentOperation(operationId)) {
        await _disposeCurrentSandbox(sandbox);
        return;
      }

      eventBus.dispatch(SandboxChangedEvent(sandbox, isFlutterApp: isFlutter));

      eventBus.dispatch(const LogEvent('Loading compiled module...'));
      await sandbox.loadModule(code: codeToLoad);
      if (!_isCurrentOperation(operationId)) {
        await _disposeCurrentSandbox(sandbox);
        return;
      }

      eventBus.dispatch(const LogEvent('Running application...'));
      if (isFlutter) {
        await sandbox.runApp(libraryUri);
      } else {
        await sandbox.runMain(libraryUri);
      }
      if (!_isCurrentOperation(operationId)) {
        await _disposeCurrentSandbox(sandbox);
        return;
      }
      eventBus.dispatch(const LogEvent('App is running.'));

      _state = PreviewRunning(entrypoint);
    } on CompilationFailedException catch (e, st) {
      if (_isCurrentOperation(operationId)) {
        eventBus.dispatch(
          LogEvent('Compilation failed', level: Level.SEVERE, error: e, stackTrace: st),
        );
        _state = PreviewCompileError(entrypoint, e.message);
      }
    } catch (e, st) {
      if (_isCurrentOperation(operationId)) {
        eventBus.dispatch(LogEvent('Run failed', level: Level.SEVERE, error: e, stackTrace: st));
        _state = PreviewCompileError(entrypoint, e.toString());
      }
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Hot reloads the currently active execution session compiler changes into
  /// the sandbox.
  Future<void> hotReloadCode() async {
    final entry = state.entrypoint;
    if (entry == null) {
      return;
    }
    if (_busy) {
      return;
    }
    final operationId = _beginOperation();
    final sandbox = _sandbox;
    if (sandbox == null) {
      return;
    }
    eventBus.dispatch(LogEvent('Hot reload $entry'));
    eventBus.dispatch(const LogEvent('Starting hot reload...'));

    _state = PreviewHotReloading(entry);
    notifyListeners();

    try {
      eventBus.dispatch(const LogEvent('Preparing compiler...'));
      var compiler = _hotReloadCompiler;
      if (compiler == null) {
        final newCompiler = await workspaceRepository.startHotReloadCompiler(
          Uri.parse(entry),
        );
        if (!_isCurrentOperation(operationId)) {
          await newCompiler.close();
          return;
        }
        _hotReloadCompiler = newCompiler;
        compiler = newCompiler;
      }

      eventBus.dispatch(const LogEvent('Compiling changes...'));
      final result = await compiler.compile();
      if (!_isCurrentOperation(operationId)) {
        return;
      }
      eventBus.dispatch(LogEvent(result.log ?? ''));

      eventBus.dispatch(const LogEvent('Applying hot reload...'));
      await sandbox.hotReload(
        code: result.code,
        librariesToReload: result.compiledLibraryUris.map(Uri.parse).toList(),
      );
      if (!_isCurrentOperation(operationId)) {
        return;
      }

      eventBus.dispatch(const LogEvent('Hot reload completed successfully.'));
      _lastCompiledCode = result.code;
      _state = PreviewRunning(entry);
    } on HotReloadRejectedException catch (e, st) {
      if (_isCurrentOperation(operationId)) {
        eventBus.dispatch(
          LogEvent('Hot reload rejected', level: Level.WARNING, error: e, stackTrace: st),
        );
        _state = PreviewCompileError(entry, e.message);
      }
    } catch (e, st) {
      if (_isCurrentOperation(operationId)) {
        eventBus.dispatch(
          LogEvent('Hot reload failed', level: Level.SEVERE, error: e, stackTrace: st),
        );
        _state = PreviewCompileError(entry, e.toString());
      }
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Terminates execution, disposes the preview sandbox, and closes compiler
  /// sessions.
  Future<void> stopCode() async {
    if (_state is PreviewStopping) {
      return;
    }
    final operationId = _beginOperation();
    eventBus.dispatch(const LogEvent('Stopping app...'));
    _state = PreviewStopping();
    _lastCompiledCode = null;
    notifyListeners();
    var operationStillCurrent = true;

    try {
      final sandbox = _sandbox;
      if (sandbox != null) {
        await _disposeCurrentSandbox(sandbox);
      } else {
        await _detachSandboxConsole();
      }
      final hotReloadCompiler = _hotReloadCompiler;
      _hotReloadCompiler = null;
      if (hotReloadCompiler != null) {
        await hotReloadCompiler.close();
      }
      eventBus.dispatch(const LogEvent('Stopped app.'));
    } finally {
      operationStillCurrent = _isCurrentOperation(operationId);
    }

    if (!operationStillCurrent) {
      return;
    }

    _state = PreviewInitial();
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _attachSandboxConsole(PreviewSandbox sandbox) async {
    await _detachSandboxConsole();
    _sandboxConsoleSubscription = sandbox.onConsole.listen((event) {
      final level = switch (event.level.name) {
        'warn' => Level.WARNING,
        'error' => Level.SEVERE,
        'info' || 'log' => Level.INFO,
        _ => Level.INFO,
      };

      final isSystemLog =
          event.message.startsWith('Starting application from') ||
          event.message.startsWith('Hot restarting application from');

      if (_isFlutter || isSystemLog) {
        eventBus.dispatch(LogEvent('[app] ${event.message}', level: level));
      } else {
        _appLogs.add(ConsoleEntry(message: event.message, level: level));
        notifyListeners();
      }
    });
    _sandboxErrorSubscription = sandbox.onError.listen((event) {
      if (_isFlutter) {
        eventBus.dispatch(LogEvent('[app] ${event.message}', level: Level.SEVERE));
      } else {
        _appLogs.add(ConsoleEntry(message: event.message, level: Level.SEVERE));
        notifyListeners();
      }
    });
    _sandboxRejectionSubscription = sandbox.onUnhandledRejection.listen((event) {
      if (_isFlutter) {
        eventBus.dispatch(LogEvent('[app] ${event.message}', level: Level.SEVERE));
      } else {
        _appLogs.add(ConsoleEntry(message: event.message, level: Level.SEVERE));
        notifyListeners();
      }
    });
  }

  Future<void> _detachSandboxConsole() async {
    await _sandboxConsoleSubscription?.cancel();
    _sandboxConsoleSubscription = null;
    await _sandboxErrorSubscription?.cancel();
    _sandboxErrorSubscription = null;
    await _sandboxRejectionSubscription?.cancel();
    _sandboxRejectionSubscription = null;
  }

  int _beginOperation() => ++_operationId;

  bool _isCurrentOperation(int operationId) => _operationId == operationId;

  Future<void> _disposeCurrentSandbox(PreviewSandbox sandbox) async {
    if (!identical(_sandbox, sandbox)) {
      return;
    }
    await _detachSandboxConsole();
    _sandbox = null;
    sandbox.dispose();
    eventBus.dispatch(const SandboxChangedEvent(null, isFlutterApp: false));
  }

  @override
  void dispose() {
    _disposed = true;
    _operationId++;
    unawaited(_detachSandboxConsole());
    _sandbox?.dispose();
    _sandbox = null;
    unawaited(_hotReloadCompiler?.close());
    _hotReloadCompiler = null;
    super.dispose();
  }
}
