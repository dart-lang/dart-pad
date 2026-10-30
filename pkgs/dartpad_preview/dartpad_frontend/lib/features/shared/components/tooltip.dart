// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';

class Tooltip extends StatefulComponent {
  const Tooltip({
    required this.child,
    this.message,
    this.waitDuration = const Duration(milliseconds: 500),
    this.cooldownDuration = const Duration(milliseconds: 500),
    super.key,
  });

  final Component child;
  final String? message;
  final Duration waitDuration;
  final Duration cooldownDuration;

  @visibleForTesting
  static void resetCooldown() {
    _TooltipState._cooldownTimer?.cancel();
    _TooltipState._cooldownTimer = null;
    _TooltipState._showImmediately = false;
  }

  @override
  State<Tooltip> createState() => _TooltipState();

  @css
  static List<StyleRule> get styles => _TooltipState.styles;
}

class _TooltipState extends State<Tooltip> {
  final GlobalNodeKey<web.HTMLElement> _tooltipKey = GlobalNodeKey();
  web.HTMLElement? _targetElement;
  Timer? _showTimer;
  bool _isTooltipVisible = false;

  static Timer? _cooldownTimer;
  static bool _showImmediately = false;

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(component.cooldownDuration, () {
      _showImmediately = false;
    });
  }

  void _enterAnchor() {
    _cooldownTimer?.cancel();
  }

  void _onMouseEnter(web.Event event) {
    final message = component.message;
    if (message == null || message.isEmpty) {
      return;
    }

    _targetElement = event.currentTarget as web.HTMLElement?;
    _enterAnchor();

    if (_showImmediately) {
      setState(() {
        _isTooltipVisible = true;
      });
      context.binding.addPostFrameCallback(_adjustTooltipPosition);
    } else {
      _showTimer?.cancel();
      _showTimer = Timer(component.waitDuration, () {
        setState(() {
          _isTooltipVisible = true;
          _showImmediately = true;
        });
        context.binding.addPostFrameCallback(_adjustTooltipPosition);
      });
    }
  }

  void _onMouseLeave(web.Event event) {
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
    final targetElement = _targetElement;
    final tooltip = _tooltipKey.currentNode;
    if (targetElement == null || tooltip == null) {
      return;
    }

    final buttonRect = targetElement.getBoundingClientRect();
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
    final message = component.message;
    if (message == null || message.isEmpty) {
      return component.child;
    }

    return Component.fragment([
      Component.apply(
        events: {
          'mouseenter': _onMouseEnter,
          'mouseleave': _onMouseLeave,
        },
        child: component.child,
      ),
      if (_isTooltipVisible)
        div(
          key: _tooltipKey,
          classes: 'custom-tooltip${message.contains('\n') ? ' rich-tooltip' : ''}',
          [
            if (message.contains('\n')) ...[
              span(classes: 'tooltip-title', [.text(message.split('\n')[0])]),
              span(classes: 'tooltip-desc', [.text(message.substring(message.indexOf('\n') + 1))]),
            ] else
              .text(message),
          ],
        ),
    ]);
  }

  static List<StyleRule> get styles => [
    css.keyframes('tooltip-fade-in', {
      '0%': const Styles(opacity: 0),
      '100%': const Styles(opacity: 1),
    }),
    css('.custom-tooltip', [
      css('&').styles(
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
        backgroundColor: colorSurface,
      ),
      css('&.rich-tooltip').styles(
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
        color: colorOnSurface,
        fontSize: 11.px,
        fontWeight: .w400,
        lineHeight: 1.4.em,
      ),
    ]),
  ];
}
