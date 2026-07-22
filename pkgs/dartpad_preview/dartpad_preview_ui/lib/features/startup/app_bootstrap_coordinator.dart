// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:logging/logging.dart';

import '../editor/single_file_editor_view_model.dart';
import '../shared/app_event_bus.dart';
import '../workspace/workspace_repository.dart';

/// Discrete phases of the application startup shown to the user.
enum BootstrapStatus {
  idle('Editor ready'),
  starting('Starting analyzer…'),
  ready('Analyzer ready'),
  failed('Analyzer unavailable');

  const BootstrapStatus(this.label);
  final String label;
}

/// Coordinates application startup without delaying the first frame.
///
/// - [events]: shared event bus for dispatching log and status events.
/// - [editor]: the editor view model that receives the workspace once ready.
/// - [onChanged]: called when [status] changes so the UI can rebuild.
final class AppBootstrapCoordinator {
  AppBootstrapCoordinator({
    required this.events,
    required this.editor,
    required this.onChanged,
  });

  /// Shared event bus for dispatching log and status events.
  final AppEventBus events;

  /// The editor view model that receives the workspace once ready.
  final SingleFileEditorViewModel editor;

  /// Called when [status] changes so the UI can rebuild.
  final void Function() onChanged;

  StreamSubscription<AnalyzerActivity>? _analyzerSubscription;
  WorkspaceRepository? _repository;
  Future<void>? _startFuture;
  Future<void>? _pubGetFuture;
  BootstrapStatus status = BootstrapStatus.idle;
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  /// Starts the application services in the following order:
  ///
  /// 1. Creates the transient workspace.
  /// 2. Subscribes to analyzer activity.
  /// 3. Starts `pub get` in the background.
  /// 4. Initializes the analyzer and attaches it to the editor.
  /// 5. Marks the application startup as ready.
  ///
  /// Repeated calls return the same startup future.
  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _setStatus(BootstrapStatus.starting);
    final generation = ++_generation;

    try {
      final repository = await _createWorkspace(generation);
      if (repository == null) {
        return;
      }
      _repository = repository;
      _subscribeToAnalyzerActivity(repository);
      _pubGetFuture = _runPubGet(repository);
      await _initializeAnalyzer(repository, generation);

      if (_isCurrentGeneration(generation)) {
        _setStatus(BootstrapStatus.ready);
        events.dispatch(const LogEvent('Startup complete.'));
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        _setStatus(BootstrapStatus.failed);
        events.dispatch(
          LogEvent(
            'Startup failed. The editor remains usable; reload to retry.',
            level: Level.SEVERE,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
  }

  Future<WorkspaceRepository?> _createWorkspace(int generation) async {
    final repository = await WorkspaceRepository.create(
      events: events,
      readLatestMainSource: () => editor.source,
    );
    if (!_isCurrentGeneration(generation)) {
      await repository.close();
      return null;
    }
    return repository;
  }

  void _subscribeToAnalyzerActivity(WorkspaceRepository repository) {
    _analyzerSubscription = repository.languageServerClient.analyzerActivityStream.listen(
      (activity) => _logAnalyzerActivity(repository, activity),
    );
  }

  Future<void> _initializeAnalyzer(
    WorkspaceRepository repository,
    int generation,
  ) async {
    await repository.languageServerClient.codeMirrorLspClient.initialized;
    if (!_isCurrentGeneration(generation)) {
      return;
    }
    editor.attachWorkspace(repository);
    events.dispatch(const LogEvent('LSP initialized and attached to main.dart.'));
  }

  Future<void> _runPubGet(WorkspaceRepository repository) async {
    try {
      await repository.pubGet();
      editor.refreshSemanticHighlighting();
    } catch (error, stackTrace) {
      if (!_disposed) {
        events.dispatch(
          LogEvent(
            'pub get failed.',
            level: Level.SEVERE,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
  }

  bool _isCurrentGeneration(int generation) => !_disposed && generation == _generation;

  void _setStatus(BootstrapStatus value) {
    status = value;
    onChanged();
  }

  void _logAnalyzerActivity(
    WorkspaceRepository repository,
    AnalyzerActivity activity,
  ) {
    switch (activity) {
      case AnalyzerStatusActivity(:final isAnalyzing):
        events.dispatch(LogEvent(isAnalyzing ? 'Analyzer is working…' : 'Analyzer is idle.'));
      case AnalyzerDiagnosticsActivity(:final path):
        final entries = repository.languageServerClient.allDiagnostics.where((entry) => entry.fileName == path);
        for (final DiagnosticEntry(:diagnostic) in entries) {
          final level = switch (diagnostic.severity) {
            DiagnosticSeverity.error => Level.SEVERE,
            DiagnosticSeverity.warning => Level.WARNING,
            DiagnosticSeverity.info || DiagnosticSeverity.hint => Level.INFO,
          };
          events.dispatch(
            LogEvent(
              '$path:${diagnostic.line + 1}:${diagnostic.character + 1} '
              '[${diagnostic.severity.label}] ${diagnostic.message}',
              level: level,
            ),
          );
        }
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    await _startFuture;
    await _pubGetFuture;
    await _analyzerSubscription?.cancel();
    final repository = _repository;
    _repository = null;
    await repository?.close();
  }
}
