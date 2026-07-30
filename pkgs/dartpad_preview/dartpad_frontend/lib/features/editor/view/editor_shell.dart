// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// @docImport '../../shared/node_container.dart';
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Top-level layout shell that hosts the CodeMirror editor and the bootstrap
/// status indicator.
class EditorShell extends StatelessComponent {
  const EditorShell({
    required this.editor,
    required this.bootstrapLabel,
    super.key,
  });

  /// The editor component (typically a [NodeContainer] wrapping CodeMirror).
  final Component editor;

  /// Human-readable label for the current status.
  final String bootstrapLabel;

  @override
  Component build(BuildContext context) {
    return div(classes: 'ide-shell', [
      div(classes: 'editor-host', [
        editor,
        div(classes: 'bootstrap-state', [
          .text(bootstrapLabel),
        ]),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.ide-shell').styles(
      display: .flex,
      width: 100.percent,
      height: 100.vh,
      flexDirection: .column,
      backgroundColor: const Color('#1e1e1e'),
    ),
    css('.editor-host').styles(
      position: const Position.relative(),
      minHeight: 0.px,
      overflow: .hidden,
      flex: const Flex(grow: 1),
    ),
    css('.bootstrap-state').styles(
      position: Position.absolute(bottom: 12.px, left: 12.px),
      zIndex: const ZIndex(10),
      padding: .symmetric(horizontal: 10.px, vertical: 6.px),
      border: .all(color: const Color('#303030'), width: 1.px),
      radius: .circular(6.px),
      color: const Color('#858585'),
      fontSize: 11.px,
      backgroundColor: const Color.rgba(24, 24, 24, 0.85),
    ),
    css('.editor-container').styles(width: 100.percent, height: 100.percent),
    css('.editor-container .cm-editor').styles(height: 100.percent),
    css('.editor-container .cm-scroller').styles(
      overflow: .auto,
      fontFamily: const .list([
        FontFamily('Cascadia Code'),
        FontFamily('Consolas'),
        FontFamilies.monospace,
      ]),
      fontSize: 14.px,
    ),
  ];
}
