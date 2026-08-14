// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

import '../../shared/app_event_bus.dart';

@Import.onWeb('../widgets/inspector_app.dart', show: [#DevToolsInspectorApp])
import 'inspector_panel_web.imports.dart' deferred as inspector;

/// A Jaspr component that hosts the embedded Flutter Inspector panel.
class InspectorPanel extends StatelessComponent {
  const InspectorPanel({required this.events, super.key});

  final AppEventBus events;

  @override
  Component build(BuildContext context) {
    return div(classes: 'debug-console-panel', [
      FlutterEmbedView.deferred(
        styles: Styles(height: 100.percent),
        constraints: ViewConstraints(
          minWidth: 200,
          minHeight: 100,
        ),
        loadLibrary: inspector.loadLibrary(),
        builder: () => inspector.DevToolsInspectorApp(events: events),
      ),
    ]);
  }
}
