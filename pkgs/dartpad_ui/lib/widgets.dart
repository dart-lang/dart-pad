// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'theme.dart';
import 'utils.dart';

class Hyperlink extends StatefulWidget {
  final String url;
  final String? displayText;
  final TextStyle? style;

  const Hyperlink({required this.url, this.displayText, this.style, super.key});

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

  const MiniIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.small = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;
    final backgroundColor = switch (brightness) {
      Brightness.light => colorScheme.surface.darker,
      Brightness.dark => colorScheme.surface.lighter,
    };

    return Tooltip(
      message: tooltip,
      waitDuration: tooltipDelay,
      child: IconButton(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(CircleBorder()),
          backgroundColor: WidgetStatePropertyAll(backgroundColor),
        ),
        icon: Icon(icon),
        iconSize: small ? 16 : smallIconSize,
        splashRadius: small ? 16 : smallIconSize,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }
}

class RunButton extends ActionButton {
  const RunButton({super.key, super.onPressed})
    : super(
        text: 'Run',
        icon: const Icon(Icons.play_arrow, color: Colors.black, size: 20),
      );
}

class ReloadButton extends ActionButton {
  const ReloadButton({super.key, super.onPressed})
    : super(
        text: 'Reload',
        icon: const Icon(Icons.refresh, color: Colors.black, size: 20),
      );
}

abstract class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Icon icon;

  const ActionButton({
    this.onPressed,
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      waitDuration: tooltipDelay,
      child: TextButton(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return runButtonColor.withValues(alpha: 0.4);
            }

            return runButtonColor;
          }),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

// Displays messages with the status of the editor through the
// [StatusController].
class StatusWidget extends StatelessWidget {
  final StatusController status;

  const StatusWidget({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;
    final backgroundColor = switch (brightness) {
      Brightness.light => colorScheme.surface.darker,
      Brightness.dark => colorScheme.surface.lighter,
    };

    return ValueListenableBuilder(
      valueListenable: status.state,
      builder: (context, MessageStatus status, _) {
        return AnimatedOpacity(
          opacity: status.state == MessageState.closing ? 0.0 : 1.0,
          duration:
              status.state == MessageState.showing
                  ? Duration.zero
                  : animationDelay,
          curve: animationCurve,
          child: Material(
            shape: const StadiumBorder(),
            color: backgroundColor,
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = smaller ? 400.0 : 500.0;
        final height = smaller ? 325.0 : 400.0;
        final theme = Theme.of(context);

        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            title: Text(title, maxLines: 1),
            contentTextStyle: theme.textTheme.bodyMedium,
            contentPadding: const EdgeInsets.fromLTRB(
              24,
              defaultSpacing,
              24,
              8,
            ),
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
      },
    );
  }
}

class GoldenRatioCenter extends StatelessWidget {
  final Widget child;

  const GoldenRatioCenter({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Align(alignment: const Alignment(0.0, -(1.618 / 4)), child: child);
  }
}

final class Logo extends StatelessWidget {
  final String? _type;
  final double width;

  const Logo({super.key, this.width = defaultIconSize, String? type})
    : _type = type;

  @override
  Widget build(BuildContext context) {
    final assetPath = switch (_type) {
      'flutter' => 'assets/flutter_logo_192.png',
      'flame' => 'assets/flame_logo_192.png',
      'gemini' => 'assets/gemini_sparkle_192.png',
      'idx' => 'assets/idx_192.png',
      _ => 'assets/dart_logo_192.png',
    };
    return Image.asset(assetPath, width: width);
  }
}
