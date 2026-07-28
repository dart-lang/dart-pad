// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';
import '../../startup/sample_project.dart';
import '../../workspace/data/workspace_repository.dart';

/// Manages the CodeMirror editor state for a single `lib/main.dart` file,
/// including save, format, and LSP attachment.
final class SingleFileEditorViewModel extends ChangeNotifier {
  SingleFileEditorViewModel({required this.events, required this.workspaceRepository})
    : container = web.document.createElement('div') as web.HTMLElement {
    container.className = 'editor-container';
    editor = CodeMirrorEditor(
      container,
      file: filePath,
      initialDoc: sampleMainDart,
      onUpdate: (_) {
        _source = editor.text;
        _isDirty = _source != _savedSource;
        notifyListeners();
      },
      onSave: () {
        if (_disposed) {
          return;
        }
        unawaited(_save());
      },
    );
  }

  static const String filePath = 'lib/main.dart';

  /// Shared event bus for logging and cross-component communication.
  final AppEventBus events;

  final WorkspaceRepository workspaceRepository;

  final web.HTMLElement container;
  late final CodeMirrorEditor editor;

  String _source = sampleMainDart;
  String _savedSource = sampleMainDart;
  bool _isDirty = false;
  bool _disposed = false;

  String get source => _source;
  bool get isDirty => _isDirty;

  Future<void> _save() async {
    try {
      final formatted = await editor.format();
      if (!formatted) {
        events.dispatch(const LogEvent('Formatting could not be completed.'));
      }
      await workspaceRepository.root.getFile(filePath).writeContent(source);
      _markSaved();
      events.dispatch(const LogEvent('Saved lib/main.dart.'));
    } catch (error, stackTrace) {
      if (!_disposed) {
        events.dispatch(
          LogEvent('Save failed.', level: Level.SEVERE, error: error, stackTrace: stackTrace),
        );
      }
    }
  }

  void _markSaved() {
    _savedSource = source;
    _isDirty = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    editor.destroy();
    super.dispose();
  }
}
