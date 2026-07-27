// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

import 'features/editor/view/editor_shell.dart';
import 'features/editor/view_model/single_file_editor_view_model.dart';
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

/// Composition root – wires all services and drives the startup lifecycle.
class AppState extends State<App> {
  late final AppEventBus _events;
  late final BrowserConsoleObserver _console;
  late final SingleFileEditorViewModel _editor;
  late final AppBootstrapCoordinator _bootstrap;

  @override
  void initState() {
    super.initState();
    _events = AppEventBus();
    _bootstrap = AppBootstrapCoordinator(
      events: _events,
      onChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _editor = SingleFileEditorViewModel(events: _events);
    _console = BrowserConsoleObserver(_events);

    // The editor DOM is committed before any worker download or SDK setup.
    context.binding.addPostFrameCallback(_bootstrap.start);
  }

  @override
  Component build(BuildContext context) {
    return ListenableBuilder(
      listenable: _editor,
      builder: (context) {
        return EditorShell(
          editor: NodeContainer(_editor.container),
          bootstrapLabel: _bootstrap.status.label,
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    // Stop producers before their consumers and the shared event stream.

    _editor.dispose();
    await _bootstrap.dispose();
    _console.dispose();
    await _events.dispose();
  }
}
