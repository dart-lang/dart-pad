// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

import 'features/editor/editor_shell.dart';
import 'features/editor/single_file_editor_view_model.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/browser_console_observer.dart';
import 'features/shared/node_container.dart';
import 'features/startup/app_bootstrap_coordinator.dart';

/// The deliberately small first production slice of DartPad Preview.
class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> {
  late final AppEventBus _events;
  late final BrowserConsoleObserver _console;
  late final SingleFileEditorViewModel _editor;
  late final AppBootstrapCoordinator _startup;
  bool _startupScheduled = false;

  @override
  void initState() {
    super.initState();
    _events = AppEventBus();
    _console = BrowserConsoleObserver(_events);
    _editor = SingleFileEditorViewModel(
      events: _events,
      onChanged: _refresh,
    );
    _startup = AppBootstrapCoordinator(
      events: _events,
      editor: _editor,
      onChanged: _refresh,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Component build(BuildContext context) {
    if (!_startupScheduled) {
      _startupScheduled = true;
      // The editor DOM is committed before any worker download or SDK setup.
      context.binding.addPostFrameCallback(_startup.start);
    }

    return EditorShell(
      editor: NodeContainer(_editor.container),
      bootstrapLabel: _startup.status.label,
    );
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    // Stop producers before their consumers and the shared event stream.
    await _editor.dispose();
    await _startup.dispose();
    await _console.dispose();
    await _events.dispose();
  }
}
