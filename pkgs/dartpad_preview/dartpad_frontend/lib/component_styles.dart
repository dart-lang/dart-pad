// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';

//TODO: move styles to components when next Jaspr version is released
/// Styles for client components, kept separate from their `package:web`
/// dependencies so Jaspr can evaluate them on the Dart VM.
/// This is a temporary solution until the next Jaspr version is released
List<StyleRule> get componentStyles => [
  css('.ide-shell').styles(
    display: .flex,
    width: 100.percent,
    height: 100.vh,
    flexDirection: .column,
    backgroundColor: const Color('#1e1e1e'),
  ),
  css('.editor-host').styles(
    display: .flex,
    minWidth: .zero,
    minHeight: 0.px,
    overflow: .hidden,
    flexDirection: .column,
    flex: const Flex(grow: 1),
  ),
  css('.status-bar').styles(
    minHeight: 24.px,
    padding: .symmetric(horizontal: 10.px),
    border: .only(
      top: .solid(color: const Color('#303030'), width: 1.px),
    ),
    overflow: .hidden,
    color: const Color('#858585'),
    fontSize: 11.px,
    lineHeight: 24.px,
    textOverflow: .ellipsis,
    whiteSpace: .noWrap,
    backgroundColor: const Color('#181818'),
  ),
  css('.status-bar.error').styles(color: const Color('#ff8a8a')),
  css('.editor-tabs').styles(
    display: .flex,
    minHeight: 36.px,
    overflow: const .only(x: .auto, y: .hidden),
    flex: const .shrink(0),
    backgroundColor: const Color('#181818'),
  ),
  css('.editor-tab').styles(
    display: .flex,
    minWidth: 96.px,
    maxWidth: 180.px,
    padding: .only(left: 12.px, right: 8.px),
    border: .only(
      right: .solid(color: const Color('#303030'), width: 1.px),
      top: .solid(color: Colors.transparent, width: 2.px),
    ),
    cursor: .pointer,
    userSelect: .none,
    alignItems: .center,
    gap: .all(6.px),
    color: const Color('#a8a8a8'),
    backgroundColor: const Color('#181818'),
  ),
  css('.editor-tab.active').styles(
    border: .only(
      top: .solid(color: const Color('#7aa2f7'), width: 2.px),
    ),
    color: const Color('#e8e8e8'),
    backgroundColor: const Color('#1e1e1e'),
  ),
  css('.editor-tab:hover').styles(backgroundColor: const Color('#252525')),
  css('.editor-tab-name').styles(
    minWidth: .zero,
    overflow: .hidden,
    flex: const Flex(grow: 1, basis: .zero),
    fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
    fontSize: 12.px,
    textOverflow: .ellipsis,
    whiteSpace: .noWrap,
  ),
  css('.editor-tab-dirty-dot').styles(
    width: 7.px,
    height: 7.px,
    radius: .circular(4.px),
    flex: const .shrink(0),
    backgroundColor: const Color('#d4d4d4'),
  ),
  css('.editor-tab-action').styles(
    display: .flex,
    width: 18.px,
    height: 18.px,
    padding: .zero,
    border: .none,
    radius: .circular(4.px),
    cursor: .pointer,
    justifyContent: .center,
    alignItems: .center,
    color: const Color('#b8b8b8'),
    fontSize: 11.px,
    backgroundColor: Colors.transparent,
  ),
  css('.editor-tab-action:hover').styles(
    color: const Color('#ffffff'),
    backgroundColor: const Color('#3a3a3a'),
  ),
  css('.editor-tab-action.close:hover').styles(
    color: const Color('#ff8a8a'),
    backgroundColor: const Color('#4a2525'),
  ),
  css('.editor-stack').styles(
    position: const .relative(),
    minHeight: .zero,
    flex: const Flex(grow: 1, basis: .zero),
  ),
  css('.editor-tab-slot').styles(
    position: .absolute(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
    opacity: 0,
    pointerEvents: .none,
  ),
  css('.editor-tab-slot.active').styles(
    position: const .relative(),
    height: 100.percent,
    opacity: 1,
    pointerEvents: .auto,
  ),
  css('.editor-container').styles(
    display: .flex,
    height: 100.percent,
    minWidth: .zero,
    overflow: .hidden,
    flex: const Flex(grow: 1, basis: .zero),
    backgroundColor: const Color('#1e1e1e'),
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
];
