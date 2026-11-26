// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';

/// A circular badge showing a diagnostic severity indicator letter (e.g. 'E', 'W', 'I', 'H')
/// used in the problems panel and the bottom panel tabs.
final class BottomPanelIndicator extends StatelessComponent {
  /// Creates an indicator displaying the badge for a diagnostic [severity].
  ///
  /// If [label] is omitted, defaults to [DiagnosticSeverity.label].
  /// [isVisible] defaults to `true`. When set to `false`, the element remains in the
  /// DOM as a hidden placeholder with `aria-hidden="true"` to prevent cumulative
  /// layout shifts (CLS).
  const BottomPanelIndicator({
    required this.severity,
    this.label,
    this.isVisible = true,
    super.key,
  });

  /// Creates an indicator displaying the [DiagnosticSeverity.error] badge.
  ///
  /// If [label] is omitted, defaults to [DiagnosticSeverity.label].
  /// [isVisible] defaults to `true`. When set to `false`, the element remains in the
  /// DOM as a hidden placeholder with `aria-hidden="true"` to prevent cumulative
  /// layout shifts (CLS).
  const BottomPanelIndicator.error({
    this.label,
    this.isVisible = true,
    super.key,
  }) : severity = DiagnosticSeverity.error;

  /// The diagnostic severity represented by this badge.
  final DiagnosticSeverity severity;

  /// An optional descriptive label used for accessibility (`aria-label`) and tooltip (`title`).
  ///
  /// If omitted, defaults to [DiagnosticSeverity.label].
  final String? label;

  /// Whether the badge is currently visible.
  ///
  /// When `false`, the badge remains in the layout with `visibility: hidden` and
  /// `aria-hidden: true` to preserve its dimensions and avoid layout shifts (CLS).
  final bool isVisible;

  @override
  Component build(BuildContext context) {
    final visibilityClass = isVisible ? '' : ' hidden';
    final effectiveLabel = label ?? severity.label;
    return span(
      classes: 'bottom-panel-indicator ${severity.cssClass}$visibilityClass',
      attributes: {
        if (!isVisible)
          'aria-hidden': 'true'
        else ...{
          'role': 'img',
          'aria-label': effectiveLabel,
          'title': effectiveLabel,
        },
      },
      [.text(severity.icon)],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.bottom-panel-indicator').styles(
      display: .inlineFlex,
      width: 18.px,
      height: 18.px,
      radius: .circular(999.px),
      userSelect: .none,
      justifyContent: .center,
      alignItems: .center,
      flex: const .shrink(0),
      fontSize: 11.px,
      fontWeight: .w700,
    ),
    css('.bottom-panel-indicator.hidden').styles(
      visibility: .hidden,
      pointerEvents: .none,
    ),
    css('.bottom-panel-indicator.error').styles(
      color: colorOnSurface,
      backgroundColor: colorError.withOpacity(0.2),
    ),
    css('.bottom-panel-indicator.warning').styles(
      color: colorOnSurface,
      backgroundColor: colorWarning.withOpacity(0.2),
    ),
    css('.bottom-panel-indicator.info, .bottom-panel-indicator.hint').styles(
      color: colorOnSurface,
      backgroundColor: colorInfo.withOpacity(0.2),
    ),
  ];
}
