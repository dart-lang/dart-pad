// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';

import '../../../app_styles.dart';

/// Styles for CodeMirror integration components within the editor container.
///
/// This includes styles for:
/// - General buttons (`.cm-button`)
/// - LSP hover tooltips (`.cm-lsp-hover-tooltip`)
/// - LSP rename panels (`.cm-lsp-rename-panel`)
/// - Search panels (`.cm-search`)
/// - General panels and tooltips (`.cm-panels`, `.cm-tooltip`)
/// - Selection action popups (`.cm-selection-action-tooltip`)
/// - Diagnostic hover toolbars (`.cm-diagnostic-hover-toolbar`)
@css
List<StyleRule> get codemirrorStyles => [
  css('.editor-container').styles(
    display: .flex,
    height: 100.percent,
    minWidth: .zero,
    overflow: .hidden,
    flex: const Flex(grow: 1, basis: .zero),
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-editor').styles(
    position: const .relative(),
    height: 100.percent,
    minWidth: .zero,
    flex: const Flex(grow: 1, basis: .zero),
  ),
  css('.editor-container .cm-scroller').styles(
    overflow: .auto,
    fontFamily: const .list([
      FontFamily('Cascadia Code'),
      FontFamily('Consolas'),
      FontFamilies.monospace,
    ]),
    fontSize: 14.px,
    raw: {'overscroll-behavior': 'none'},
  ),
  css('.editor-container .cm-button').styles(
    padding: .symmetric(vertical: 6.px, horizontal: 12.px),
    border: .all(color: colorBorder, width: 1.px),
    radius: .circular(6.px),
    cursor: .pointer,
    transition: .combine([
      Transition('background-color', duration: 200.ms),
      Transition('border-color', duration: 200.ms),
      Transition('color', duration: 200.ms),
    ]),
    color: colorOnSurface,
    fontSize: 13.px,
    fontWeight: .w500,
    backgroundColor: colorSurface,
    raw: {
      'background-image': 'none',
    },
  ),
  css('.editor-container .cm-button:hover').styles(
    border: .all(color: colorPrimary, width: 1.px),
    backgroundColor: const Color('#333333'),
  ),
  css('.editor-container .cm-lsp-hover-tooltip').styles(
    maxHeight: 300.px,
    padding: .symmetric(vertical: 8.px, horizontal: 12.px),
    overflow: const .only(y: .auto),
  ),
  css('.editor-container .cm-lsp-hover-tooltip code').styles(
    padding: .symmetric(vertical: 2.px, horizontal: 4.px),
    radius: .circular(3.px),
    fontSize: 12.px,
  ),
  css('.editor-container .cm-lsp-hover-tooltip hr').styles(
    height: 1.px,
    margin: .symmetric(vertical: 8.px, horizontal: (-12).px),
    border: .none,
    backgroundColor: colorOnSurface,
  ),
  css('.editor-container .cm-lsp-hover-tooltip p').styles(
    margin: .only(top: 0.px, right: 0.px, bottom: 8.px, left: 0.px),
  ),
  css('.editor-container .cm-lsp-hover-tooltip p:last-child').styles(
    margin: .only(bottom: 0.px),
  ),
  css('.editor-container .cm-lsp-hover-tooltip pre').styles(
    padding: .symmetric(vertical: 8.px, horizontal: 12.px),
    margin: .only(top: (-8).px, right: (-12).px, bottom: 8.px, left: (-12).px),
    border: .only(
      bottom: BorderSide(color: colorBorder, width: 1.px, style: BorderStyle.solid),
    ),
    radius: const .all(.zero),
    overflow: const .only(x: .auto),
  ),
  css('.editor-container .cm-lsp-hover-tooltip pre code').styles(
    padding: .zero,
    fontSize: 12.px,
    backgroundColor: Colors.transparent,
  ),
  css('.editor-container .cm-lsp-hover-tooltip pre, .editor-container .cm-lsp-hover-tooltip code').styles(
    fontFamily: const .list([
      FontFamily('Menlo'),
      FontFamily('Monaco'),
      FontFamily('Consolas'),
      FontFamilies.courierNew,
      FontFamilies.monospace,
    ]),
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-panel.cm-lsp-rename-panel').styles(
    display: .flex,
    padding: .symmetric(vertical: 8.px, horizontal: 12.px),
    flexDirection: .row,
    alignItems: .center,
    gap: .all(10.px),
    color: colorOnContainer,
    fontFamily: const .list([FontFamily('Inter'), FontFamilies.sansSerif]),
    fontSize: 13.px,
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-panel.cm-lsp-rename-panel .cm-button').styles(
    padding: .symmetric(vertical: 6.px, horizontal: 14.px),
    margin: .zero,
    border: .none,
    radius: .circular(6.px),
    transition: Transition('opacity', duration: 200.ms),
    alignSelf: .end,
    color: colorOnPrimary,
    fontSize: 13.px,
    fontWeight: .w500,
    backgroundColor: colorPrimary,
    raw: {
      'background-image': 'none',
    },
  ),
  css('.editor-container .cm-panel.cm-lsp-rename-panel .cm-button:hover').styles(
    opacity: 0.9,
  ),
  css('.editor-container .cm-panel.cm-lsp-rename-panel .cm-textfield').styles(
    width: .auto,
    padding: .symmetric(vertical: 6.px, horizontal: 10.px),
    margin: .zero,
    border: .all(color: colorBorder, width: 1.px),
    radius: .circular(4.px),
    outline: const Outline(style: .none),
    color: colorOnContainer,
    fontSize: 13.px,
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-panel.cm-lsp-rename-panel .cm-textfield:focus').styles(
    border: .all(color: colorPrimary, width: 1.px),
  ),
  css('.editor-container .cm-panel.cm-lsp-rename-panel label').styles(
    display: .inlineFlex,
    margin: .zero,
    alignItems: .center,
    gap: .all(6.px),
    color: colorOnContainer,
    fontWeight: .w500,
  ),
  css('.editor-container .cm-panel.cm-search').styles(
    position: const .relative(),
    padding: .symmetric(vertical: 8.px, horizontal: 12.px),
    color: colorOnContainer,
    fontFamily: const .list([FontFamily('Inter'), FontFamilies.sansSerif]),
    fontSize: 13.px,
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-panel.cm-search [name=close]').styles(
    display: .flex,
    position: .absolute(top: 8.px, right: 8.px),
    width: 20.px,
    height: 20.px,
    border: .none,
    radius: .circular(4.px),
    cursor: .pointer,
    transition: .combine([
      Transition('background-color', duration: 200.ms),
      Transition('color', duration: 200.ms),
    ]),
    justifyContent: .center,
    alignItems: .center,
    color: colorOnContainer,
    fontSize: 16.px,
    backgroundColor: Colors.transparent,
  ),
  css('.editor-container .cm-panel.cm-search [name=close]:hover').styles(
    color: colorOnContainer,
    backgroundColor: colorContainer,
  ),
  css(
    '.editor-container .cm-panel.cm-search input, .editor-container .cm-panel.cm-search button, .editor-container .cm-panel.cm-search label',
  ).styles(
    margin: .only(top: 4.px, right: 6.px, bottom: 4.px, left: 0.px),
  ),
  css('.editor-container .cm-panel.cm-search input[type=checkbox]').styles(
    cursor: .pointer,
    raw: {
      'accent-color': 'var(--color-primary)',
      'width': '14px',
      'height': '14px',
      'margin-right': '4px',
    },
  ),
  css(
    '.editor-container .cm-panel.cm-search input[type=text], .editor-container .cm-panel.cm-search .cm-textfield',
  ).styles(
    width: 160.px,
    padding: .symmetric(vertical: 4.px, horizontal: 8.px),
    border: .all(color: colorBorder, width: 1.px),
    radius: .circular(4.px),
    outline: const Outline(style: .none),
    transition: Transition('border-color', duration: 200.ms),
    color: colorOnContainer,
    fontSize: 13.px,
    backgroundColor: colorContainer,
  ),
  css(
    '.editor-container .cm-panel.cm-search input[type=text]:focus, .editor-container .cm-panel.cm-search .cm-textfield:focus',
  ).styles(
    border: .all(color: colorPrimary, width: 1.px),
  ),
  css('.editor-container .cm-panel.cm-search label').styles(
    display: .inlineFlex,
    cursor: .pointer,
    flexDirection: .row,
    alignItems: .center,
    gap: .all(4.px),
    color: colorOnSurface,
    fontSize: 12.px,
  ),
  css('.editor-container .cm-panels').styles(
    border: .only(
      top: .solid(color: colorBorder, width: 1.px),
    ),
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-tooltip').styles(
    maxWidth: 450.px,
    border: .all(color: colorBorder, width: 1.px),
    radius: .circular(6.px),
    shadow: BoxShadow(
      offsetX: 0.px,
      offsetY: 4.px,
      blur: 16.px,
      color: const Color.rgba(0, 0, 0, 0.4),
    ),
    color: colorOnSurface,
    fontFamily: const .list([
      FontFamily('Inter'),
      FontFamily('-apple-system'),
      FontFamily('BlinkMacSystemFont'),
      FontFamily('Segoe UI'),
      FontFamily('Roboto'),
      FontFamilies.sansSerif,
    ]),
    fontSize: 13.px,
    lineHeight: 1.4.em,
    backgroundColor: colorSurface,
  ),
  css('.editor-container .cm-tooltip a').styles(
    color: colorPrimary,
    textDecoration: const TextDecoration(line: .none),
  ),
  css('.editor-container .cm-tooltip a:hover').styles(
    textDecoration: const TextDecoration(line: .underline),
  ),
  css('.editor-container .cm-cmd-click-link').styles(
    cursor: .pointer,
    raw: {
      'text-decoration': 'underline !important',
    },
  ),
  css('.editor-container .cm-tooltip img').styles(
    height: Unit.auto,
    maxWidth: 100.percent,
  ),
  css('.editor-container .cm-tooltip-arrow::after').styles(
    raw: {
      'border-top-color': colorContainer.value,
      'border-bottom-color': colorContainer.value,
    },
  ),
  css('.editor-container .cm-tooltip-arrow::before').styles(
    raw: {
      'border-top-color': colorBorder.value,
      'border-bottom-color': colorBorder.value,
    },
  ),
  css('.editor-container .cm-selection-action-tooltip').styles(
    padding: .zero,
    radius: .circular(6.px),
    raw: {
      'background-color': 'rgba(30, 30, 30, 0.75) !important',
      'backdrop-filter': 'blur(10px) !important',
      '-webkit-backdrop-filter': 'blur(10px) !important',
      'border': '1px solid rgba(255, 255, 255, 0.15) !important',
    },
  ),
  css('.editor-container .cm-selection-action-btn').styles(
    display: .flex,
    padding: .symmetric(vertical: 6.px, horizontal: 12.px),
    border: Border.none,
    radius: .circular(5.px),
    cursor: .pointer,
    alignItems: .center,
    color: colorOnSurface,
    backgroundColor: Colors.transparent,
    raw: {
      'gap': '8px',
      'font-family': 'inherit',
      'font-size': '12px',
      'font-weight': '500',
      'transition': 'background-color 0.2s ease',
    },
  ),
  css('.editor-container .cm-selection-action-btn:hover').styles(
    raw: {
      'background-color': 'rgba(255, 255, 255, 0.1) !important',
    },
  ),
  css('.editor-container .cm-selection-action-shortcut').styles(
    padding: .symmetric(vertical: 2.px, horizontal: 4.px),
    radius: .circular(3.px),
    color: const Color.rgba(255, 255, 255, 0.6),
    fontSize: 10.px,
    backgroundColor: const Color.rgba(255, 255, 255, 0.15),
  ),
  css('.editor-container .cm-diagnostic-hover-toolbar').styles(
    display: .flex,
    padding: .symmetric(vertical: 4.px, horizontal: 6.px),
    radius: .circular(6.px),
    gap: .all(6.px),
    backgroundColor: colorContainer,
  ),
  css('.editor-container .cm-diagnostic-toolbar-btn').styles(
    display: .inlineFlex,
    padding: .symmetric(vertical: 4.px, horizontal: 10.px),
    border: .all(color: colorBorder, width: 1.px),
    radius: .circular(4.px),
    cursor: .pointer,
    transition: .combine([
      Transition('background-color', duration: 150.ms, curve: .ease),
      Transition('border-color', duration: 150.ms, curve: .ease),
      Transition('color', duration: 150.ms, curve: .ease),
      Transition('opacity', duration: 150.ms, curve: .ease),
    ]),
    alignItems: .center,
    color: colorPrimary,
    fontSize: 12.px,
    fontWeight: .w500,
    backgroundColor: colorContainer,
    raw: {
      'background-image': 'none',
    },
  ),
  css('.editor-container .cm-diagnostic-toolbar-btn:not(:disabled):hover').styles(
    border: .all(color: colorPrimary, width: 1.px),
    color: colorOnPrimary,
    backgroundColor: colorPrimary,
  ),
  css('.editor-container .cm-diagnostic-toolbar-btn:disabled').styles(
    border: .all(color: colorBorder, width: 1.px),
    opacity: .5,
    cursor: .notAllowed,
    color: colorOnContainer,
    backgroundColor: colorContainer,
  ),
];
