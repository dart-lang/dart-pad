// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import 'problems_panel.dart';

/// The bottom panel showing a "Problems" tab with diagnostics.
class BottomPanel extends StatelessComponent {
  const BottomPanel({
    required this.diagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    required this.showProblems,
    required this.onShowProblems,
    super.key,
  });

  /// All current diagnostics from the language server.
  final List<DiagnosticEntry> diagnostics;

  /// The currently active editor file path, used to highlight matching rows.
  final String activeFile;

  /// Called when the user clicks a diagnostic row.
  final void Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  /// Whether the problems panel content is visible.
  final bool showProblems;

  /// Shows the problems panel.
  final void Function() onShowProblems;

  @override
  Component build(BuildContext context) {
    return div(classes: 'bottom-panel', [
      _buildTabs(),
      if (showProblems) _buildContent(),
    ]);
  }

  Component _buildTabs() {
    return div(classes: 'bottom-panel-tabs', [
      _BottomPanelTabButton(
        label: 'Problems',
        countLabel: diagnostics.length.toString(),
        active: showProblems,
        onClick: onShowProblems,
      ),
    ]);
  }

  Component _buildContent() {
    return div(
      classes: 'bottom-panel-content',
      [
        ProblemsPanel(
          diagnostics: diagnostics,
          activeFile: activeFile,
          onOpenDiagnostic: onOpenDiagnostic,
        ),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.bottom-panel').styles(
      display: .flex,
      height: 100.percent,
      flexDirection: .column,
      flex: const .shrink(0),
    ),
    css('.bottom-panel .bottom-panel-tabs').styles(
      display: .flex,
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .stretch,
      flex: const .shrink(0),
    ),
    css('.bottom-panel .bottom-panel-content').styles(
      display: .flex,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.bottom-panel .problems-panel').styles(
      height: 100.percent,
      minHeight: .zero,
      maxHeight: 100.percent,
      margin: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.bottom-panel .bottom-panel-tab').styles(
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
      color: colorOnSurfaceVariant,
      fontSize: 12.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
    ),
    css('.bottom-panel .bottom-panel-tab:hover').styles(
      color: colorOnSurface,
      backgroundColor: colorOnSurface.withOpacity(0.06),
    ),
    css('.bottom-panel .bottom-panel-tab.active').styles(
      color: colorOnSurface,
      backgroundColor: colorContainer,
    ),
    css('.bottom-panel .bottom-panel-tab-count').styles(
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
    css('.bottom-panel .bottom-panel-tabs-spacer').styles(
      flex: const Flex(grow: 1),
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
