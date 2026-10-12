// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../icons.dart';
import '../panel_layout_controller.dart';

/// Reversible collapse controls for the horizontal workspace chrome.
final class CollapsiblePanel extends StatelessComponent {
  const CollapsiblePanel({required this.panel, required this.layout, required this.child, super.key});

  final WorkspacePanel panel;
  final PanelLayoutController layout;
  final Component child;

  @override
  Component build(BuildContext context) {
    final presentation = layout[panel];
    final expanded = presentation == PanelPresentation.expanded;
    final label = '${expanded ? 'Collapse' : 'Show'} ${panel.label}';
    return div(
      classes: 'collapsible-panel ${presentation.name}',
      attributes: {'data-panel': panel.queryName},
      styles: Styles(display: presentation == PanelPresentation.hidden ? Display.none : Display.flex),
      [
        div(
          classes: 'collapsible-panel-content',
          styles: Styles(display: expanded ? Display.flex : Display.none),
          [child],
        ),
        button(
          classes: 'panel-toggle',
          attributes: {'type': 'button', 'aria-label': label, 'title': label, 'aria-expanded': '$expanded'},
          onClick: () => layout.toggle(panel),
          [
            Icon(expanded ? 'expand_less' : 'expand_more', size: 16),
            if (!expanded) span([.text(panel.label)]),
          ],
        ),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.collapsible-panel').styles(
      minWidth: .zero,
      alignItems: .stretch,
      flex: const Flex.shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.collapsible-panel-content').styles(
      minWidth: .zero,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.panel-toggle').styles(
      display: .flex,
      minHeight: 22.px,
      padding: .symmetric(horizontal: 4.px),
      border: .none,
      cursor: .pointer,
      alignItems: .center,
      gap: Gap.all(4.px),
      color: colorOnSurface,
      fontSize: 11.px,
      backgroundColor: Colors.transparent,
    ),
    css('.panel-toggle:hover, .panel-toggle:focus-visible').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
  ];
}
