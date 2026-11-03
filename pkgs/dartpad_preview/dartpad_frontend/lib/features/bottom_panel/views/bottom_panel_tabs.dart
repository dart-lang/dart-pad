// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/icon_button.dart';
import '../../shared/icons.dart';
import '../bottom_panel_state.dart';
import '../view_models/console_view_model.dart';
import 'bottom_panel_indicator.dart';

/// Desktop tabs or a compact Console disclosure for the bottom panel.
final class BottomPanelTabs extends StatelessComponent {
  const BottomPanelTabs({
    required this.problemsCount,
    required this.console,
    required this.activeTab,
    required this.onSelectTab,
    this.isCollapsed = false,
    this.showProblems = true,
    this.onCollapse,
    this.onExpand,
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

  /// Whether the Problems tab is available in this layout.
  final bool showProblems;

  /// An optional callback invoked to collapse the panel content.
  final VoidCallback? onCollapse;

  /// An optional callback invoked to expand the panel content.
  final VoidCallback? onExpand;

  @override
  Component build(BuildContext context) {
    if (!showProblems) {
      final onToggle = isCollapsed ? onExpand ?? () => onSelectTab(BottomPanelTab.console) : onCollapse;
      return div(classes: 'bottom-panel-tabs bottom-panel-console-header', [
        button(
          classes: 'bottom-panel-console-title',
          attributes: {
            'type': 'button',
            'aria-expanded': '${!isCollapsed}',
            'aria-controls': 'bottom-panel-content',
          },
          onClick: onToggle,
          [
            const span(classes: 'bottom-panel-console-label', [.text('Console')]),
            _buildConsoleIndicator(),
          ],
        ),
        if (!isCollapsed) _buildClearButton(),
        button(
          classes: 'bottom-panel-console-toggle',
          attributes: {
            'type': 'button',
            'aria-label': isCollapsed ? 'Show console' : 'Hide console',
            'aria-expanded': '${!isCollapsed}',
            'aria-controls': 'bottom-panel-content',
          },
          onClick: onToggle,
          [
            Icon(isCollapsed ? 'expand_less' : 'expand_more', size: 18, attributes: const {'aria-hidden': 'true'}),
          ],
        ),
      ]);
    }
    return div(
      classes: 'bottom-panel-tabs',
      attributes: const {'role': 'tablist'},
      [
        if (showProblems)
          _BottomPanelTabButton(
            label: 'Problems',
            countLabel: problemsCount.toString(),
            active: !isCollapsed && activeTab == BottomPanelTab.problems,
            onClick: () => onSelectTab(BottomPanelTab.problems),
          ),
        _BottomPanelTabButton(
          label: 'Console',
          active: !isCollapsed && activeTab == BottomPanelTab.console,
          indicator: _buildConsoleIndicator(),
          onClick: () => onSelectTab(BottomPanelTab.console),
        ),
        const div(classes: 'bottom-panel-tabs-spacer', []),
        if (!isCollapsed && activeTab == BottomPanelTab.console) _buildClearButton(),
        if (!isCollapsed && onCollapse != null)
          IconButton(
            tooltip: 'Hide bottom panel',
            label: 'Hide bottom panel',
            icon: 'expand_more',
            iconSize: 20,
            classes: 'bottom-panel-btn',
            onClick: (_) => onCollapse!(),
          ),
        if (isCollapsed && onExpand != null)
          IconButton(
            tooltip: 'Show bottom panel',
            label: 'Show bottom panel',
            icon: 'expand_more',
            iconSize: 20,
            classes: 'bottom-panel-btn bottom-panel-expand-btn',
            onClick: (_) => onExpand!(),
          ),
      ],
    );
  }

  Component _buildConsoleIndicator() => ListenableBuilder(
    listenable: console,
    builder: (_) => BottomPanelIndicator.error(
      label: console.hasErrors ? 'Console contains errors' : null,
      isVisible: console.hasErrors,
    ),
  );

  Component _buildClearButton() => IconButton(
    icon: 'playlist_remove',
    iconSize: 20,
    tooltip: 'Clear console',
    label: 'Clear console',
    classes: 'bottom-panel-btn',
    onClick: (_) => console.clear(),
  );

  @css
  static List<StyleRule> get styles => [
    css('.bottom-panel-console-toggle, .bottom-panel-console-title').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: 44.px,
      padding: .symmetric(horizontal: 10.px),
      border: .none,
      cursor: .pointer,
      alignItems: .center,
      gap: .all(6.px),
      color: colorOnSurface,
      fontSize: 12.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
      // Native tap highlights can fade at the old position after the panel moves.
      raw: {'-webkit-tap-highlight-color': 'transparent'},
    ),
    css('.bottom-panel-console-toggle:active, .bottom-panel-console-title:active').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.06),
    ),
    css('.bottom-panel-console-toggle').styles(
      width: 44.px,
      padding: .zero,
      justifyContent: .center,
      flex: const .shrink(0),
    ),
    css('.bottom-panel-console-title').styles(
      padding: .symmetric(horizontal: 10.px),
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.bottom-panel-console-toggle:focus-visible, .bottom-panel-console-title:focus-visible').styles(
      outline: Outline(style: .solid, color: colorPrimary, width: OutlineWidth(2.px)),
      raw: {'outline-offset': '-2px'},
    ),
    css('.bottom-panel-console-header .bottom-panel-btn').styles(
      width: 44.px,
      height: 44.px,
      margin: .zero,
    ),
    css('.bottom-panel-tabs').styles(
      display: .flex,
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .stretch,
      flex: const .shrink(0),
      backgroundColor: colorSurface,
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
      backgroundColor: colorTabInactive,
    ),
    css('.bottom-panel-tab:hover').styles(
      color: colorOnSurface,
      backgroundColor: colorTabInactive.highlight(colorOnContainer, 0.05),
    ),
    css('.bottom-panel-tab.active').styles(
      color: colorOnSurface,
      backgroundColor: colorTabActive,
    ),
    css('.bottom-panel-tab.active:hover').styles(
      backgroundColor: colorTabActive.highlight(colorOnContainer, 0.05),
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
    css('.bottom-panel-expand-btn > .material-symbols-outlined').styles(transform: .rotate(180.deg)),
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
