// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Displays the editor content for every open tab.
///
/// Inactive editors remain mounted so they retain their view state.
final class EditorStack extends StatelessComponent {
  /// Creates an editor stack for [openTabs].
  const EditorStack({
    required this.openTabs,
    required this.activeFile,
    super.key,
  });

  /// The tabs whose editor contents are mounted.
  final List<EditorTab<Component>> openTabs;

  /// The path of the visible editor tab.
  final String activeFile;

  @override
  Component build(BuildContext context) {
    return div(classes: 'editor-stack', [
      for (final tab in openTabs)
        div(
          key: ValueKey('slot-${tab.path}'),
          classes: tab.path == activeFile ? 'editor-tab-slot active' : 'editor-tab-slot',
          [tab.build()],
        ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.editor-stack', [
      css('&').styles(
        position: const .relative(),
        minHeight: .zero,
        flex: const Flex(grow: 1, basis: .zero),
      ),
      css('.editor-tab-slot', [
        css('&').styles(
          position: .absolute(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
          opacity: 0,
          pointerEvents: .none,
        ),
        css('&.active').styles(
          position: const .relative(),
          height: 100.percent,
          opacity: 1,
          pointerEvents: .auto,
        ),
      ]),
    ]),
  ];
}
