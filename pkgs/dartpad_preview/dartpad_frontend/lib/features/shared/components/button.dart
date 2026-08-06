// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';

/// A reusable styled button component with consistent appearance across DartPad.
class Button extends StatelessComponent {
  const Button({
    required this.label,
    this.disabled = false,
    this.onClick,
    this.classes,
    super.key,
  });

  /// The text label displayed on the button.
  final String label;

  /// Whether the button is disabled.
  final bool disabled;

  /// Called when the button is clicked. Not called when [disabled] is true.
  final VoidCallback? onClick;

  /// Additional CSS classes to apply.
  final String? classes;

  @override
  Component build(BuildContext context) {
    return button(
      classes: 'dp-button${classes != null ? ' $classes' : ''}',
      attributes: {
        'title': label,
        'aria-label': label,
        if (disabled) 'disabled': '',
      },
      onClick: disabled ? null : onClick,
      [.text(label)],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.dp-button', [
      css('&').styles(
        display: .inlineFlex,
        padding: .symmetric(vertical: 8.px, horizontal: 12.px),
        border: .none,
        radius: .circular(5.px),
        outline: const Outline(style: .none),
        cursor: .pointer,
        justifyContent: .center,
        alignItems: .center,
        color: colorOnPrimary,
        fontSize: 12.px,
        fontWeight: FontWeight.w500,
        whiteSpace: .noWrap,
        backgroundColor: colorPrimary,
      ),
      css('&:not(:disabled):hover').styles(
        color: colorOnPrimary,
        backgroundColor: colorPrimary.highlight(colorOnPrimary, 0.1),
      ),
      css('&:disabled').styles(
        opacity: 0.45,
        cursor: .defaultCursor,
      ),
    ]),
  ];
}
