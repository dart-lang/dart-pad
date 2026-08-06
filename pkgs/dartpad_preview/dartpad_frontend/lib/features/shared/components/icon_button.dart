// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';

/// A button component displaying an icon or a custom child component,
/// with support for tooltips, labels, and disabled states.
class IconButton extends StatefulComponent {
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
  State<IconButton> createState() => _IconButtonState();

  @css
  static List<StyleRule> get styles => _IconButtonState.styles;
}

class _IconButtonState extends State<IconButton> {
  final GlobalNodeKey<web.HTMLElement> _buttonKey = GlobalNodeKey();
  Timer? _showTimer;
  bool _isTooltipVisible = false;

  static Timer? _cooldownTimer;
  static bool _showImmediately = false;

  static void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(milliseconds: 500), () {
      _showImmediately = false;
    });
  }

  static void _enterButton() {
    _cooldownTimer?.cancel();
  }

  void _onMouseEnter() {
    final tooltipText = component.tooltip ?? component.label;
    if (tooltipText == null) {
      return;
    }

    _enterButton();

    if (_showImmediately) {
      setState(() {
        _isTooltipVisible = true;
      });
      context.binding.addPostFrameCallback(_adjustTooltipPosition);
    } else {
      _showTimer?.cancel();
      _showTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() {
          _isTooltipVisible = true;
          _showImmediately = true;
        });
        context.binding.addPostFrameCallback(_adjustTooltipPosition);
      });
    }
  }

  void _onMouseLeave() {
    _showTimer?.cancel();
    if (_isTooltipVisible) {
      setState(() {
        _isTooltipVisible = false;
      });
      _startCooldown();
    }
  }

  void _adjustTooltipPosition() {
    if (!mounted || !_isTooltipVisible) {
      return;
    }
    final buttonElement = _buttonKey.currentNode;
    if (buttonElement == null) {
      return;
    }
    final tooltip = buttonElement.querySelector('.custom-tooltip') as web.HTMLElement?;
    if (tooltip == null) {
      return;
    }

    final buttonRect = buttonElement.getBoundingClientRect();
    final tooltipRect = tooltip.getBoundingClientRect();
    final windowWidth = web.window.innerWidth;
    final windowHeight = web.window.innerHeight;

    final buttonCenter = buttonRect.left + buttonRect.width / 2;
    double left = buttonCenter - tooltipRect.width / 2;

    if (left < 8) {
      left = 8;
    } else if (left + tooltipRect.width > windowWidth - 8) {
      left = windowWidth - tooltipRect.width - 8.0;
    }

    double top = buttonRect.bottom + 4.0;
    if (top + tooltipRect.height > windowHeight - 8) {
      top = buttonRect.top - tooltipRect.height - 4.0;
    }

    tooltip.style.setProperty('left', '${left}px');
    tooltip.style.setProperty('top', '${top}px');
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final classNames = [
      'icon-button',
      if (component.classes case final extraClasses? when extraClasses.isNotEmpty) extraClasses,
    ].join(' ');

    final attributes = <String, String>{};
    final tooltipText = component.tooltip ?? component.label;
    if (tooltipText != null) {
      attributes['aria-label'] = tooltipText;
    }
    if (component.disabled) {
      attributes['disabled'] = 'true';
    }

    return button(
      key: _buttonKey,
      classes: classNames,
      attributes: attributes,
      events: {
        if (component.onClick != null && !component.disabled) 'click': component.onClick!,
        'mouseenter': (event) => _onMouseEnter(),
        'mouseleave': (event) => _onMouseLeave(),
      },
      [
        if (component.child != null)
          component.child!
        else if (component.icon != null)
          Icon(
            component.icon!,
            size: component.iconSize,
          ),
        if (_isTooltipVisible && tooltipText != null)
          div(
            classes: 'custom-tooltip${tooltipText.contains('\n') ? ' rich-tooltip' : ''}',
            [
              if (tooltipText.contains('\n')) ...[
                span(classes: 'tooltip-title', [.text(tooltipText.split('\n')[0])]),
                span(classes: 'tooltip-desc', [.text(tooltipText.substring(tooltipText.indexOf('\n') + 1))]),
              ] else
                .text(tooltipText),
            ],
          ),
      ],
    );
  }

  static List<StyleRule> get styles => [
    css.keyframes('tooltip-fade-in', {
      '0%': const Styles(opacity: 0),
      '100%': const Styles(opacity: 1),
    }),
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
        backgroundColor: colorContainerHigh,
      ),
      css('&:disabled').styles(
        cursor: .notAllowed,
      ),
      css('&:disabled > *:not(.custom-tooltip)').styles(
        opacity: 0.5,
      ),
      css('.custom-tooltip').styles(
        position: .fixed(left: (-9999).px, top: (-9999).px),
        zIndex: const ZIndex(2000),
        padding: .symmetric(vertical: 4.px, horizontal: 8.px),
        border: .all(color: colorBorder, width: 1.px),
        radius: .circular(4.px),
        pointerEvents: .none,
        animation: Animation(name: 'tooltip-fade-in', duration: 120.ms, curve: .easeOut, fillMode: .forwards),
        color: colorOnSurface,
        fontSize: 12.px,
        fontWeight: .w500,
        whiteSpace: .noWrap,
        backgroundColor: colorContainerLow,
      ),
      css('.custom-tooltip.rich-tooltip').styles(
        display: .flex,
        width: 220.px,
        padding: Padding.all(8.px),
        flexDirection: .column,
        alignItems: .center,
        gap: Gap.all(2.px),
        whiteSpace: .normal,
      ),
      css('.tooltip-title').styles(
        color: colorOnSurface,
        fontSize: 11.5.px,
        fontWeight: .w600,
      ),
      css('.tooltip-desc').styles(
        color: colorOnSurfaceVariant,
        fontSize: 11.px,
        fontWeight: .w400,
        lineHeight: 1.4.em,
      ),
    ]),
  ];
}
