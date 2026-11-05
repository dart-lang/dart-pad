// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';
import 'tooltip.dart';

/// A button component displaying an icon or a custom child component,
/// with support for tooltips, labels, and disabled states.
class IconButton extends StatelessComponent {
  const IconButton({
    this.icon,
    this.child,
    this.onClick,
    this.disabled = false,
    this.tooltip,
    this.classes,
    this.iconSize = 18.0,
    this.label,
    super.key,
  }) : assert(icon != null || child != null, 'Either icon or child must be provided.');

  final String? icon;
  final Component? child;
  final FutureOr<void> Function(web.Event event)? onClick;
  final bool disabled;
  final String? tooltip;
  final String? classes;
  final double iconSize;
  final String? label;

  @override
  Component build(BuildContext context) {
    final classNames = [
      'icon-button',
      if (classes case final extraClasses? when extraClasses.isNotEmpty) extraClasses,
    ].join(' ');

    final attributes = <String, String>{};
    if (label case final l? when l.isNotEmpty) {
      attributes['aria-label'] = l;
    }
    if (disabled) {
      attributes['disabled'] = 'true';
    }

    return Tooltip(
      message: tooltip,
      child: button(
        classes: classNames,
        attributes: attributes,
        events: {
          if (onClick != null && !disabled) 'click': onClick!,
        },
        [
          if (child != null)
            child!
          else if (icon != null)
            Icon(
              icon!,
              size: iconSize,
            ),
        ],
      ),
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.icon-button', [
      css('&').styles(
        display: .flex,
        position: const .relative(),
        width: 28.px,
        height: 28.px,
        padding: .zero,
        border: .none,
        radius: .circular(4.px),
        cursor: .pointer,
        transition: Transition('background-color', duration: 150.ms, curve: .ease),
        justifyContent: .center,
        alignItems: .center,
        color: colorOnSurface,
        backgroundColor: Colors.transparent,
      ),
      css('& > *').styles(
        raw: {'flex-shrink': '0'},
      ),
      css('&:not(:disabled):hover').styles(
        backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
      ),
      css('&:disabled').styles(
        cursor: .notAllowed,
      ),
      css('&:disabled > *').styles(
        opacity: 0.5,
      ),
    ]),
  ];
}
