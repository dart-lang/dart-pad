// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../codemirror/code_mirror_tab.dart';

/// Switches the active Markdown tab between its rendered preview and source.
final class MarkdownViewSwitch extends StatelessComponent {
  const MarkdownViewSwitch({required this.tab, super.key});

  final CodeMirrorTab tab;

  @override
  Component build(BuildContext context) => div(
    classes: 'markdown-view-switch',
    attributes: const {'role': 'group', 'aria-label': 'Markdown view'},
    [
      for (final preview in [true, false])
        button(
          classes: 'markdown-view-button',
          attributes: {'aria-pressed': '${tab.isMarkdownPreview == preview}'},
          onClick: () => tab.setMarkdownPreview(preview: preview),
          [Component.text(preview ? 'Preview' : 'Edit')],
        ),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.markdown-view-switch').styles(
      display: .flex,
      height: 100.percent,
      alignItems: .stretch,
      gap: .all(2.px),
      flex: const .shrink(0),
    ),
    css('.markdown-view-button').styles(
      display: .flex,
      height: 100.percent,
      padding: .symmetric(horizontal: 12.px),
      boxSizing: .borderBox,
      border: .none,
      radius: .circular(4.px),
      cursor: .pointer,
      userSelect: .none,
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      justifyContent: .center,
      alignItems: .center,
      color: colorOnSurface,
      fontFamily: defaultFontFamily,
      fontSize: 12.px,
      backgroundColor: Colors.transparent,
    ),
    css('.markdown-view-button:hover').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.markdown-view-button[aria-pressed="true"]').styles(
      radius: .circular(4.px),
      color: colorOnPrimary,
      backgroundColor: colorPrimary,
    ),
    css('.markdown-view-button[aria-pressed="true"]:hover').styles(
      backgroundColor: colorPrimary,
    ),
    css('.markdown-tab, .markdown-source, .markdown-rendered').styles(height: 100.percent, minWidth: .zero),
    css('.markdown-tab [hidden]').styles(display: .none),
    css('.markdown-preview').styles(
      height: 100.percent,
      padding: .symmetric(vertical: 20.px, horizontal: 28.px),
      boxSizing: .borderBox,
      overflow: .auto,
      color: colorOnContainer,
      fontFamily: defaultFontFamily,
      fontSize: 14.px,
      backgroundColor: colorContainer,
      raw: {'line-height': '1.65', 'overflow-wrap': 'anywhere'},
    ),
    css('.markdown-preview > :first-child').styles(margin: const .only(top: .zero)),
    css('.markdown-preview h1, .markdown-preview h2').styles(
      padding: .only(bottom: 8.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
    ),
    css('.markdown-preview a').styles(color: colorPrimary),
    css('.markdown-preview code').styles(
      padding: .symmetric(vertical: 2.px, horizontal: 4.px),
      radius: .circular(4.px),
      fontFamily: monospaceFontFamily,
      backgroundColor: colorSurface,
    ),
    css('.markdown-preview pre').styles(
      padding: .all(12.px),
      radius: .circular(6.px),
      overflow: const .only(x: .auto),
      backgroundColor: colorSurface,
    ),
    css('.markdown-preview pre code').styles(padding: .zero),
    css('.markdown-preview blockquote').styles(
      padding: .only(left: 16.px),
      margin: const .symmetric(horizontal: .zero),
      border: .only(
        left: .solid(color: colorBorder, width: 4.px),
      ),
      color: colorOnSurface,
    ),
    css('.markdown-preview table').styles(
      display: .block,
      maxWidth: 100.percent,
      overflow: const .only(x: .auto),
      raw: {'border-collapse': 'collapse'},
    ),
    css('.markdown-preview th, .markdown-preview td').styles(
      padding: .symmetric(vertical: 6.px, horizontal: 12.px),
      border: .all(color: colorBorder, width: 1.px),
    ),
    css('.markdown-preview img').styles(maxWidth: 100.percent),
    css('.markdown-preview hr').styles(
      border: .only(
        top: .solid(color: colorBorder, width: 1.px),
      ),
    ),
  ];
}
