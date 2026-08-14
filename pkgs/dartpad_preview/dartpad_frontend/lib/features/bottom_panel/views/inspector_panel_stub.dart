// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/app_event_bus.dart';

/// Stub component for InspectorPanel when Flutter/dart:ui is not available (e.g. in tests).
class InspectorPanel extends StatelessComponent {
  const InspectorPanel({required this.events, super.key});

  final AppEventBus events;

  @override
  Component build(BuildContext context) {
    return const div(classes: 'debug-console-panel', []);
  }
}
