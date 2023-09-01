// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

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
        onTap: () => url_launcher.launchUrl(Uri.parse(widget.url)),
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
  final bool small;
  final VoidCallback? onPressed;
  final Color? color;

  const MiniIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.small = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const smallIconContrants = BoxConstraints(minWidth: 30, minHeight: 30);

    final colorScheme = Theme.of(context).colorScheme;
    final darkTheme = colorScheme.darkMode;
    final backgroundColor =
        darkTheme ? colorScheme.surface.lighter : colorScheme.primary.darker;

    return Tooltip(
      message: tooltip,
      waitDuration: tooltipDelay,
      child: Material(
        elevation: 2,
        type: MaterialType.circle,
        color: backgroundColor,
        child: IconButton(
          icon: Icon(icon),
          iconSize: small ? 18 : smallIconSize,
          splashRadius: small ? 18 : smallIconSize,
          visualDensity: VisualDensity.compact,
          constraints: small ? smallIconContrants : null,
          onPressed: onPressed,
          color: color,
        ),
      ),
    );
  }
}

class ProgressWidget extends StatelessWidget {
  final StatusController status;

  const ProgressWidget({
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final darkTheme = colorScheme.darkMode;
    final backgroundColor =
        darkTheme ? colorScheme.surface.lighter : colorScheme.primary.darker;

    return ValueListenableBuilder(
      valueListenable: status.state,
      builder: (context, MessageStatus status, _) {
        return AnimatedOpacity(
          opacity: status.state == MessageState.closing ? 0.0 : 1.0,
          duration: status.state == MessageState.showing
              ? Duration.zero
              : animationDelay,
          curve: animationCurve,
          child: Material(
            color: backgroundColor,
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: denseSpacing,
                vertical: 4.0,
              ),
              child: Text(
                status.message,
                // style: subtleText,
              ),
            ),
          ),
        );
      },
    );
  }
}

class MediumDialog extends StatelessWidget {
  final String title;
  final bool smaller;
  final Widget child;

  const MediumDialog({
    required this.title,
    this.smaller = false,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var width = smaller ? 400.0 : 500.0;
      var height = smaller ? 325.0 : 400.0;

      return PointerInterceptor(
        child: AlertDialog(
          title: Text(title),
          contentTextStyle: Theme.of(context).textTheme.bodyMedium,
          contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: height,
                child: ClipRect(child: child),
              ),
              const Divider(),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }
}

class GoldenRatioCenter extends StatelessWidget {
  final Widget? child;

  const GoldenRatioCenter({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: const Alignment(0.0, -(1.618 / 4)),
      child: child,
    );
  }
}

class ValueBuilder<T> extends StatelessWidget {
  final ValueListenable<T> listenable;
  final Widget Function(T value) builder;

  const ValueBuilder(
    this.listenable,
    this.builder, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (BuildContext context, T value, Widget? child) {
        return builder(value);
      },
    );
  }
}
