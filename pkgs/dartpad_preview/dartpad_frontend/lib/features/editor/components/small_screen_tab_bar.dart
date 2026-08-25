// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';

/// A tab displayed in [SmallScreenTabBar].
enum SmallScreenTab {
  code,
  output,
}

/// The Code / Output [SmallScreenTabBar] displayed on small screens.
final class SmallScreenTabBar extends StatelessComponent {
  const SmallScreenTabBar({
    this.selectedTab = .code,
    required this.onTabSelected,
    super.key,
  });

  /// The tab currently displayed in the editor area.
  final SmallScreenTab selectedTab;

  /// Called when the displayed tab changes.
  final void Function(SmallScreenTab tab) onTabSelected;

  @override
  Component build(BuildContext context) {
    return div(classes: 'small-screen-tab-bar', [
      button(
        classes: 'small-screen-tab-bar-tab ${selectedTab == .code ? 'active' : ''}',
        events: {'click': (_) => onTabSelected(.code)},
        attributes: const {'type': 'button'},
        const [
          span(classes: 'small-screen-tab-bar-label', [Component.text('Code')]),
        ],
      ),
      button(
        classes: 'small-screen-tab-bar-tab ${selectedTab == .output ? 'active' : ''}',
        events: {'click': (_) => onTabSelected(.output)},
        attributes: const {'type': 'button'},
        const [
          span(classes: 'small-screen-tab-bar-label', [Component.text('Output')]),
        ],
      ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.small-screen-tab-bar').styles(
      display: .flex,
      height: 40.px,
      minHeight: 40.px,
      padding: .only(bottom: 4.px),
      alignItems: .center,
      backgroundColor: colorSurface,
    ),
    css('.small-screen-tab-bar-tab').styles(
      display: .flex,
      position: const .relative(),
      height: 100.percent,
      padding: .zero,
      border: .none,
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      flex: const Flex(grow: 1, basis: .zero),
      color: colorOnSurface,
      fontSize: 14.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
    ),
    css('.small-screen-tab-bar-tab:hover').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.04),
    ),
    css('.small-screen-tab-bar-tab.active').styles(
      color: colorPrimary,
      fontWeight: .w600,
    ),
    css('.small-screen-tab-bar-tab.active::after').styles(
      content: '',
      position: .absolute(bottom: 0.px, left: 50.percent),
      width: 48.px,
      height: 3.px,
      radius: .circular(2.px),
      backgroundColor: colorPrimary,
      raw: {'transform': 'translateX(-50%)'},
    ),
    css('.small-screen-tab-bar-label').styles(
      whiteSpace: .noWrap,
    ),
  ];
}
