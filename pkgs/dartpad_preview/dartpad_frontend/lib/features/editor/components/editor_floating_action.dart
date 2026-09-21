// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Shared positioning and presentation for an action floating over the editor.
final class EditorFloatingAction extends StatelessComponent {
  /// Creates a consistently positioned action over the editor.
  const EditorFloatingAction({
    required this.className,
    required this.busy,
    required this.child,
    super.key,
  });

  /// Additional CSS class identifying the concrete editor action.
  final String className;

  /// Whether the action is currently performing an asynchronous operation.
  final bool busy;

  /// Interactive control displayed inside the floating container.
  final Component child;

  @override
  Component build(BuildContext context) => div(
    classes: 'editor-floating-action $className',
    attributes: {'aria-busy': busy ? 'true' : 'false'},
    [child],
  );

  @css
  static List<StyleRule> get styles => [
    css('.editor-floating-action', [
      css('&').styles(
        display: .flex,
        position: .absolute(right: 32.px, top: 16.px),
        zIndex: const ZIndex(20),
        alignItems: .center,
      ),
      css('.dp-button').styles(
        shadow: BoxShadow(
          offsetX: 0.px,
          offsetY: 2.px,
          blur: 6.px,
          color: const Color.rgba(0, 0, 0, 0.20),
        ),
      ),
    ]),
    css('html[data-theme="dark"] .editor-floating-action .dp-button').styles(
      shadow: .none,
    ),
  ];
}
