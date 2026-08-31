// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/components/button.dart';
import '../../shared/events/log_event.dart';

/// Displays path-aware Pub actions for an active Pub metadata file.
///
/// Manages its own busy state internally, disabling the action buttons while
/// a Pub operation is in progress.
final class PubspecEditorActions extends StatefulComponent {
  /// Creates the floating Pub actions for [activeFile].
  const PubspecEditorActions({
    required this.activeFile,
    required this.saveAllFiles,
    required this.events,
    required this.onPubGet,
    required this.onPubClean,
    super.key,
  });

  /// The path shown in the active editor tab.
  final String activeFile;

  /// Persists all open editor files before Pub resolves dependencies.
  final Future<void> Function() saveAllFiles;

  /// Event bus used to report Pub failures to the debug console.
  final AppEventBus events;

  /// Runs Pub Get in the supplied workspace-relative directory.
  final Future<void> Function(String path) onPubGet;

  /// Runs Pub Clean in the supplied workspace-relative directory.
  final Future<void> Function(String path) onPubClean;

  @override
  State<PubspecEditorActions> createState() => _PubspecEditorActionsState();

  @css
  static List<StyleRule> get styles => [
    css('.pubspec-editor-actions').styles(
      display: .flex,
      position: .absolute(right: 32.px, top: 16.px),
      zIndex: const ZIndex(20),
      alignItems: .center,
      gap: .all(8.px),
    ),
  ];
}

class _PubspecEditorActionsState extends State<PubspecEditorActions> {
  bool _busy = false;

  /// Saves all files and runs Pub Get in [path].
  Future<void> _pubGet(String path) async {
    await _run('Pub get failed.', () async {
      try {
        await component.saveAllFiles();
      } catch (_) {
        // The editor owns and displays save failures.
        return;
      }
      await component.onPubGet(path);
    });
  }

  /// Runs Pub Clean in [path] without saving files first.
  Future<void> _pubClean(String path) async {
    await _run('Pub clean failed.', () => component.onPubClean(path));
  }

  Future<void> _run(
    String failureMessage,
    Future<void> Function() operation,
  ) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await operation();
    } catch (error, stackTrace) {
      component.events.dispatch(
        LogEvent(
          failureMessage,
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Component build(BuildContext context) {
    final fileName = workspaceContext.basename(component.activeFile);
    final directory = workspaceContext.dirname(component.activeFile);
    final isPubspecFile = fileName == 'pubspec.yaml' || fileName == 'pubspec.lock';

    // Keep the stateful component's root render object stable while switching
    // between editor tabs. Jaspr cannot safely replace an empty fragment root
    // with an element when this component is nested in the editor overlay.
    return div(classes: 'pubspec-editor-actions-host', [
      if (isPubspecFile)
        div(classes: 'pubspec-editor-actions', [
          Button(
            label: 'Pub get',
            disabled: _busy,
            onClick: () => unawaited(_pubGet(directory)),
          ),
          Button(
            label: 'Pub clean',
            disabled: _busy,
            onClick: () => unawaited(_pubClean(directory)),
          ),
        ]),
    ]);
  }
}
