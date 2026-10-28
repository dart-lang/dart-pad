// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Groups panel content and unmounts it while hidden, without a toggle control.
final class PanelVisibility extends StatelessComponent {
  const PanelVisibility({required this.visible, required this.child, this.id, super.key});

  final bool visible;
  final Component child;
  final String? id;

  @override
  Component build(BuildContext context) => Component.fragment([
    if (visible) div(id: id, classes: 'panel-visibility', [child]),
  ]);

  @css
  static List<StyleRule> get styles => [
    css('.panel-visibility').styles(
      minWidth: .zero,
      flex: const .shrink(0),
    ),
  ];
}
