// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/icon_button.dart';
import 'bottom_panel.dart';

/// The tab bar for the bottom panel.
class BottomPanelTabs extends StatelessComponent {
  const BottomPanelTabs({
    required this.problemsCount,
    required this.activeTab,
    required this.onSelectTab,
    required this.onClearConsole,
    super.key,
  });

  /// The number of current diagnostics, shown as a badge on the tab.
  final int problemsCount;

  /// The currently active tab.
  final BottomPanelTab activeTab;

  /// Called when a tab is clicked.
  final void Function(BottomPanelTab tab) onSelectTab;

  /// Clears the console's output.
  final void Function() onClearConsole;

  @override
  Component build(BuildContext context) {
    return div(classes: 'bottom-panel-tabs', [
      _BottomPanelTabButton(
        label: 'Problems',
        countLabel: problemsCount.toString(),
        active: activeTab == BottomPanelTab.problems,
        onClick: () => onSelectTab(BottomPanelTab.problems),
      ),
      _BottomPanelTabButton(
        label: 'Console',
        active: activeTab == BottomPanelTab.console,
        onClick: () => onSelectTab(BottomPanelTab.console),
      ),
      const div(classes: 'bottom-panel-tabs-spacer', []),
      if (activeTab == BottomPanelTab.console)
        IconButton(
          icon: 'playlist_remove',
          iconSize: 20,
          tooltip: 'Clear console',
          label: 'Clear console',
          classes: 'bottom-panel-clear-btn',
          onClick: (_) => onClearConsole(),
        ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.bottom-panel-tabs').styles(
      display: .flex,
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .stretch,
      flex: const .shrink(0),
    ),
    css('.bottom-panel-tab').styles(
      display: .inlineFlex,
      padding: .symmetric(vertical: 7.px, horizontal: 14.px),
      border: .none,
      outline: const Outline(style: .none),
      cursor: .pointer,
      userSelect: .none,
      transition: .combine([
        Transition('background', duration: 150.ms, curve: .ease),
        Transition('color', duration: 150.ms, curve: .ease),
        Transition('border-color', duration: 150.ms, curve: .ease),
      ]),
      alignItems: .center,
      gap: Gap.all(6.px),
      color: colorOnSurface,
      fontSize: 12.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
    ),
    css('.bottom-panel-tab:hover').styles(
      color: colorOnSurface,
      backgroundColor: colorOnSurface.withOpacity(0.06),
    ),
    css('.bottom-panel-tab.active').styles(
      color: colorOnSurface,
      backgroundColor: colorOnSurface.withOpacity(0.08),
    ),
    css('.bottom-panel-tab-count').styles(
      display: .inlineFlex,
      padding: .symmetric(vertical: 1.px, horizontal: 4.px),
      radius: .circular(8.px),
      justifyContent: .center,
      alignItems: .center,
      color: colorOnPrimary,
      fontSize: 10.px,
      fontWeight: .w600,
      backgroundColor: colorPrimary,
    ),
    css('.bottom-panel-tabs-spacer').styles(
      flex: const Flex(grow: 1),
    ),
    css('.bottom-panel-clear-btn').styles(
      margin: .only(right: 8.px),
      alignSelf: .center,
    ),
  ];
}

class _BottomPanelTabButton extends StatelessComponent {
  const _BottomPanelTabButton({
    required this.label,
    this.countLabel,
    required this.active,
    this.onClick,
  });

  final String label;
  final String? countLabel;
  final bool active;
  final void Function()? onClick;

  @override
  Component build(BuildContext context) {
    final classes = active ? 'bottom-panel-tab active' : 'bottom-panel-tab';

    return button(
      classes: classes,
      onClick: onClick,
      [
        span(classes: 'bottom-panel-tab-label', [.text(label)]),
        if (countLabel case final countLabel?) span(classes: 'bottom-panel-tab-count', [.text(countLabel)]),
      ],
    );
  }
}
