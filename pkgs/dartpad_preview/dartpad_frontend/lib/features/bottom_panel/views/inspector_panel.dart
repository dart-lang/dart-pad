// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

import '../../shared/app_event_bus.dart';
import '../data/sandbox_vm_service.dart' if (dart.library.io) '../data/sandbox_vm_service_stub.dart';

@Import.onWeb('../widgets/inspector_app.dart', show: [#DevToolsInspectorApp])
import 'inspector_panel.imports.dart' deferred as inspector;

/// A Jaspr component that hosts the embedded Flutter Inspector panel.
class InspectorPanel extends StatefulComponent {
  const InspectorPanel({required this.events, super.key});

  final AppEventBus events;

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel> {
  SandboxVmServiceManager? _sandboxVmServiceManager;

  @override
  void initState() {
    super.initState();
    _sandboxVmServiceManager = SandboxVmServiceManager(component.events);
  }

  @override
  void dispose() {
    _sandboxVmServiceManager?.dispose();
    super.dispose();
  }

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
        builder: () => inspector.DevToolsInspectorApp(),
      ),
    ]);
  }
}
