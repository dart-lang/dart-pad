// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../shared/app_event_bus.dart';
import 'sample_project.dart';

final class SingleFileEditorViewModel {
  SingleFileEditorViewModel({
    required this.events,
    required this.onChanged,
  }) : container = web.document.createElement('div') as web.HTMLElement {
    container.className = 'editor-container';
    editor = CodeMirrorEditor(
      container,
      file: filePath,
      initialDoc: sampleMainDart,
      onUpdate: (_) {
        _source = editor.text;
        _isDirty = _source != _savedSource;
        onChanged();
      },
      onSave: _handleSave,
    );
  }

  static const String filePath = 'lib/main.dart';

  final AppEventBus events;
  final void Function() onChanged;
  final web.HTMLElement container;
  late final CodeMirrorEditor editor;

  String _source = sampleMainDart;
  String _savedSource = sampleMainDart;
  bool _isDirty = false;
  bool _disposed = false;
  WorkspaceController? _workspace;
  final Set<Future<void>> _pendingSaves = {};

  String get source => _source;
  bool get isDirty => _isDirty;

  void attachWorkspace(WorkspaceController workspace) {
    if (_disposed) {
      return;
    }
    _workspace = workspace;
    editor.attachWorkspace(workspace);
  }

  void refreshSemanticHighlighting() {
    if (!_disposed) {
      editor.triggerLspRefresh();
    }
  }

  void _handleSave() {
    if (_disposed) {
      return;
    }
    late final Future<void> save;
    save = _save().whenComplete(() => _pendingSaves.remove(save));
    _pendingSaves.add(save);
    unawaited(save);
  }

  Future<void> _save() async {
    try {
      final workspace = _workspace;
      if (workspace == null) {
        throw StateError('Cannot save because the workspace is not ready.');
      }
      final formatted = await editor.format();
      if (!formatted) {
        throw StateError('Formatting could not be completed, so the file was not saved.');
      }
      await workspace.root.getFile(filePath).writeContent(source);
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
    onChanged();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await Future.wait(_pendingSaves.toList());
    editor.destroy();
  }
}
