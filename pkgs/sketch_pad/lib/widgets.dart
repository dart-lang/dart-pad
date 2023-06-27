// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url;

import 'theme.dart';
import 'utils.dart';

class Hyperlink extends StatefulWidget {
  final String url;
  final String? displayText;
  final TextStyle? style;

  const Hyperlink({
    required this.url,
    this.displayText,
    this.style,
    Key? key,
  }) : super(key: key);

  @override
  State<Hyperlink> createState() => _HyperlinkState();
}

class _HyperlinkState extends State<Hyperlink> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    const underline = TextStyle(decoration: TextDecoration.underline);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
        setState(() => hovered = true);
      },
      onExit: (event) {
        setState(() => hovered = false);
      },
      child: GestureDetector(
        onTap: () => url.launchUrl(Uri.parse(widget.url)),
        child: Text(
          widget.displayText ?? widget.url,
          style: hovered ? underline.merge(widget.style) : widget.style,
        ),
      ),
    );
  }
}

class MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const MiniIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: tooltipDelay,
      child: IconButton(
        icon: Icon(icon),
        iconSize: smallIconSize,
        splashRadius: defaultSplashRadius,
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.all(2),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        color: color,
      ),
    );
  }
}

// todo: have a background
// todo: use rounded corners
// todo: use an elevation

class ProgressWidget extends StatelessWidget {
  final ProgressController status;

  const ProgressWidget({
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MessageStatus>(
      valueListenable: status.state,
      builder: (context, status, _) {
        return AnimatedOpacity(
          opacity: status.state == MessageState.closing ? 0.0 : 1.0,
          duration: status.state == MessageState.showing
              ? Duration.zero
              : animationDelay,
          curve: animationCurve,
          child: Text(status.message, style: subtleText),
        );
      },
    );
  }
}

class CompilingStatusWidget extends StatefulWidget {
  final ValueListenable<bool> status;

  const CompilingStatusWidget({
    required this.status,
    super.key,
  });

  @override
  State<CompilingStatusWidget> createState() => _CompilingStatusWidgetState();
}

class _CompilingStatusWidgetState extends State<CompilingStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    widget.status.addListener(_statusListener);
  }

  void _statusListener() {
    final value = widget.status.value;

    if (value) {
      controller.repeat();
    } else {
      controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkMode = theme.colorScheme.darkMode;

    final gearIcon =
        Image.asset('assets/gear-96-${darkMode ? 'light' : 'dark'}.png');

    return ValueListenableBuilder<bool>(
      valueListenable: widget.status,
      builder: (context, bool value, _) {
        return AnimatedOpacity(
          opacity: value ? 0.6 : 0.0,
          duration: animationDelay,
          child: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) {
              return Transform.rotate(
                angle: controller.value * 2 * math.pi,
                child: gearIcon,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    widget.status.removeListener(_statusListener);

    controller.dispose();

    super.dispose();
  }
}

class SplitViewDragWidget extends StatelessWidget {
  final bool vertical;

  const SplitViewDragWidget._(this.vertical, {super.key});

  factory SplitViewDragWidget.vertical({Key? key}) {
    return SplitViewDragWidget._(true, key: key);
  }

  factory SplitViewDragWidget.horizontal({Key? key}) {
    return SplitViewDragWidget._(false, key: key);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: vertical
          ? const VerticalDivider(thickness: 2)
          : const Divider(thickness: 2),
    );
  }
}
