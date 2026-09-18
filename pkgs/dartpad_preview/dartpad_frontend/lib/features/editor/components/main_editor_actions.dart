// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/components/button.dart';
import '../../shared/dart_source.dart';
import '../../shared/run_availability.dart';
import 'editor_floating_action.dart';

/// Displays a floating Run action for an active Dart file containing a `main` function.
///
/// Manages its own busy state internally, disabling the action button while
/// a run operation is in progress or when the preview cannot run an entrypoint.
final class MainEditorActions extends StatefulComponent {
  /// Creates the floating Run action for [activeFile].
  const MainEditorActions({
    required this.activeFile,
    required this.onRun,
    required this.getContent,
    required this.tabUpdates,
    required this.runAvailability,
    super.key,
  });

  /// The path shown in the active editor tab.
  final String activeFile;

  /// Retrieves the live content of the active editor file.
  final String Function() getContent;

  /// Stream of tab updates (e.g. keystrokes or edits in CodeMirror).
  final Stream<void> tabUpdates;

  /// Observable state indicating whether an entrypoint can currently be run.
  final RunAvailability runAvailability;

  /// Runs the active file as an entrypoint.
  final Future<void> Function(String path) onRun;

  @override
  State<MainEditorActions> createState() => _MainEditorActionsState();
}

final class _MainEditorActionsState extends State<MainEditorActions> {
  static const _contentUpdateDebounce = Duration(milliseconds: 150);

  bool _busy = false;
  bool _hasMain = false;
  StreamSubscription<void>? _tabUpdatesSub;
  Timer? _contentUpdateTimer;
  int _contentGeneration = 0;

  @override
  void initState() {
    super.initState();
    _hasMain = _evaluateHasMain();
    component.runAvailability.addListener(_onRunStateChanged);
    _subscribeToTabUpdates();
  }

  @override
  void didUpdateComponent(MainEditorActions oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.runAvailability != component.runAvailability) {
      oldComponent.runAvailability.removeListener(_onRunStateChanged);
      component.runAvailability.addListener(_onRunStateChanged);
    }
    if (oldComponent.tabUpdates != component.tabUpdates || oldComponent.activeFile != component.activeFile) {
      _subscribeToTabUpdates();
    }
    _hasMain = _evaluateHasMain();
  }

  @override
  void dispose() {
    _contentGeneration++;
    _tabUpdatesSub?.cancel();
    _contentUpdateTimer?.cancel();
    component.runAvailability.removeListener(_onRunStateChanged);
    super.dispose();
  }

  void _subscribeToTabUpdates() {
    _tabUpdatesSub?.cancel();
    _contentUpdateTimer?.cancel();
    final generation = ++_contentGeneration;
    _tabUpdatesSub = component.tabUpdates.listen((_) {
      if (generation != _contentGeneration) {
        return;
      }
      _contentUpdateTimer?.cancel();
      _contentUpdateTimer = Timer(_contentUpdateDebounce, () {
        if (generation == _contentGeneration) {
          _refreshHasMain();
        }
      });
    });
  }

  void _refreshHasMain() {
    final hasMain = _evaluateHasMain();
    if (hasMain == _hasMain || !mounted) {
      return;
    }
    setState(() {
      _hasMain = hasMain;
    });
  }

  void _onRunStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _evaluateHasMain() {
    if (!component.activeFile.endsWith('.dart')) {
      return false;
    }
    return dartSourceHasMain(component.getContent());
  }

  Future<void> _handleRun() async {
    if (_busy) {
      return;
    }
    if (!component.runAvailability.canRun) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await component.onRun(component.activeFile);
    } catch (_) {
      // The preview runner owns and displays failures.
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
    final isDisabled = _busy || !component.runAvailability.canRun;

    // Keep the stateful component's root render object stable while switching
    // between editor tabs. Jaspr cannot safely replace an empty fragment root
    // with an element when this component is nested in the editor overlay.
    return div(classes: 'main-editor-actions-host', [
      if (_hasMain)
        EditorFloatingAction(
          className: 'main-editor-actions',
          busy: _busy,
          child: Button(
            label: 'Run',
            disabled: isDisabled,
            onClick: () => unawaited(_handleRun()),
          ),
        ),
    ]);
  }
}
