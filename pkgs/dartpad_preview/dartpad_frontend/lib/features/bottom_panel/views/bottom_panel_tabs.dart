// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/icon_button.dart';
import '../view_models/console_view_model.dart';
import 'bottom_panel.dart';
import 'bottom_panel_indicator.dart';

/// The tab bar for the bottom panel.
final class BottomPanelTabs extends StatelessComponent {
  const BottomPanelTabs({
    required this.problemsCount,
    required this.console,
    required this.activeTab,
    required this.onSelectTab,
    this.isCollapsed = false,
    this.onCollapse,
    super.key,
  });

  /// The number of current diagnostics, shown as a badge on the tab.
  final int problemsCount;

  /// Console state observed by the error indicator.
  final ConsoleViewModel console;

  /// The currently active tab.
  final BottomPanelTab activeTab;

  /// Called when a tab is clicked.
  final void Function(BottomPanelTab tab) onSelectTab;

  /// Whether the bottom panel content is currently collapsed.
  final bool isCollapsed;

  /// An optional callback invoked to collapse the panel content.
  final VoidCallback? onCollapse;

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'bottom-panel-tabs',
      attributes: const {'role': 'tablist'},
      [
        _BottomPanelTabButton(
          label: 'Problems',
          countLabel: problemsCount.toString(),
          active: !isCollapsed && activeTab == BottomPanelTab.problems,
          onClick: () => onSelectTab(BottomPanelTab.problems),
        ),
        _BottomPanelTabButton(
          label: 'Console',
          active: !isCollapsed && activeTab == BottomPanelTab.console,
          indicator: ListenableBuilder(
            listenable: console,
            builder: (_) => BottomPanelIndicator.error(
              label: console.hasErrors ? 'Console contains errors' : null,
              isVisible: console.hasErrors,
            ),
          ),
          onClick: () => onSelectTab(BottomPanelTab.console),
        ),
        const div(classes: 'bottom-panel-tabs-spacer', []),
        if (!isCollapsed && activeTab == BottomPanelTab.console)
          IconButton(
            icon: 'playlist_remove',
            iconSize: 20,
            tooltip: 'Clear console',
            label: 'Clear console',
            classes: 'bottom-panel-btn',
            onClick: (_) => console.clear(),
          ),
        if (!isCollapsed && onCollapse != null)
          IconButton(
            tooltip: 'Hide bottom panel',
            label: 'Hide bottom panel',
            icon: 'expand_more',
            iconSize: 20,
            classes: 'bottom-panel-btn',
            onClick: (_) => onCollapse!(),
          ),
      ],
    );
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
    css('.bottom-panel-btn').styles(
      margin: .only(top: 2.px, bottom: 2.px, right: 8.px),
      alignSelf: .center,
    ),
  ];
}

/// A single tab button in [BottomPanelTabs].
final class _BottomPanelTabButton extends StatelessComponent {
  const _BottomPanelTabButton({
    required this.label,
    this.countLabel,
    this.indicator,
    required this.active,
    this.onClick,
  });

  /// The text label shown on the tab.
  final String label;

  /// An optional count badge text (e.g. number of problems).
  final String? countLabel;

  /// An optional trailing indicator component (e.g. [BottomPanelIndicator]).
  final Component? indicator;

  /// Whether this tab is currently selected.
  final bool active;

  /// Click handler for selecting this tab.
  final void Function()? onClick;

  @override
  Component build(BuildContext context) {
    final classes = active ? 'bottom-panel-tab active' : 'bottom-panel-tab';

    return button(
      classes: classes,
      onClick: onClick,
      attributes: {
        'role': 'tab',
        'aria-selected': active.toString(),
      },
      [
        span(classes: 'bottom-panel-tab-label', [.text(label)]),
        if (countLabel case final countLabel?) span(classes: 'bottom-panel-tab-count', [.text(countLabel)]),
        ?indicator,
      ],
    );
  }
}
