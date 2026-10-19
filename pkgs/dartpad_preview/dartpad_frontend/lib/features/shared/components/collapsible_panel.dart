// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../icons.dart';
import '../panel_presentation.dart';

/// The direction in which a panel closes, also used by its toggle icon.
enum CollapseDirection { up, down }

/// A panel without a draggable split, controlled entirely by its owner.
///
/// User actions request a new [state] through [onStateChanged]. Collapsed panels
/// retain a reopen control; hidden panels render nothing. Content is unmounted
/// while collapsed or hidden, so persistent state belongs outside this component.
final class CollapsiblePanel extends StatelessComponent {
  const CollapsiblePanel({
    required this.id,
    required this.label,
    required this.state,
    required this.onStateChanged,
    required this.child,
    this.showToggle = true,
    this.collapseDirection = CollapseDirection.up,
    super.key,
  });

  /// Unique DOM identifier for this panel and its accessible content reference.
  final String id;
  final String label;
  final PanelPresentation state;
  final ValueChanged<PanelPresentation> onStateChanged;
  final Component child;
  final bool showToggle;
  final CollapseDirection collapseDirection;

  @override
  Component build(BuildContext context) => Component.fragment([
    if (state != PanelPresentation.hidden) _buildPanel(),
  ]);

  Component _buildPanel() {
    final expanded = state == PanelPresentation.expanded;
    final action = '${expanded ? 'Collapse' : 'Show'} $label';
    final pointsUp = expanded == (collapseDirection == CollapseDirection.up);
    return div(
      id: id,
      classes: 'collapsible-panel ${state.name} collapse-${collapseDirection.name}${showToggle ? '' : ' no-toggle'}',
      [
        div(
          id: '$id-content',
          classes: 'collapsible-panel-content',
          [if (expanded) child],
        ),
        if (showToggle)
          button(
            classes: 'collapsible-panel-toggle',
            attributes: {
              'type': 'button',
              'title': action,
              'aria-label': action,
              'aria-expanded': '$expanded',
              'aria-controls': '$id-content',
            },
            onClick: () => onStateChanged(expanded ? PanelPresentation.collapsed : PanelPresentation.expanded),
            [Icon(pointsUp ? 'keyboard_arrow_up' : 'keyboard_arrow_down', size: 18)],
          ),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.collapsible-panel').styles(
      display: .flex,
      minWidth: .zero,
      alignItems: .stretch,
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.collapsible-panel-content').styles(
      minWidth: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.collapsible-panel-toggle').styles(
      display: .flex,
      width: 28.px,
      minHeight: 24.px,
      padding: .zero,
      border: .none,
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      flex: const .shrink(0),
      color: colorOnSurface,
      backgroundColor: Colors.transparent,
    ),
    css('.collapsible-panel-toggle:hover').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.collapsible-panel-toggle:focus-visible').styles(
      raw: {'outline': '2px solid ${colorPrimary.value}', 'outline-offset': '-2px'},
    ),
    css('.collapsible-panel.collapsed.collapse-up').styles(
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
    ),
    css('.collapsible-panel.collapsed.collapse-down').styles(
      border: .only(
        top: .solid(color: colorBorder, width: 1.px),
      ),
    ),
    css('.collapsible-panel.collapsed.no-toggle').styles(border: .none),
  ];
}
