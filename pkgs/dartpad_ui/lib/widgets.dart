// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'editor/editor.dart';
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
    super.key,
  });

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

class RunButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const RunButton({this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Run',
      waitDuration: tooltipDelay,
      child: TextButton(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)))),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) {
              if (states.contains(WidgetState.disabled)) {
                return runButtonColor.withValues(alpha: 0.4);
              }

              return runButtonColor;
            },
          ),
        ),
        onPressed: onPressed,
        child: const Row(
          children: [
            Icon(
              Icons.play_arrow,
              color: Colors.black,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Run',
              style: TextStyle(color: Colors.black),
            ),
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

  const StatusWidget({
    required this.status,
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
    return LayoutBuilder(builder: (context, constraints) {
      final width = smaller ? 400.0 : 500.0;
      final height = smaller ? 325.0 : 400.0;
      final theme = Theme.of(context);

      return PointerInterceptor(
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(title, maxLines: 1),
          contentTextStyle: theme.textTheme.bodyMedium,
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
  final Widget child;

  const GoldenRatioCenter({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0.0, -(1.618 / 4)),
      child: child,
    );
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

class PromptDialog extends StatefulWidget {
  const PromptDialog({
    required this.title,
    this.smaller = false,
    super.key,
  });

  final bool smaller;
  final String title;
  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  // TODO: let them choose Dart or Flutter
  static const _description = 'Describe the code you want to generate.';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.smaller ? 500.0 : 700.0;
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(widget.title),
        contentTextStyle: theme.textTheme.bodyMedium,
        contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
        content: SizedBox(
            width: width,
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: _description,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, controller, _) => TextButton(
              onPressed: controller.text.isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text),
              child: Text(
                'Generate',
                style: TextStyle(
                  color: controller.text.isEmpty
                      ? Theme.of(context).disabledColor
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GeneratingCodeDialog extends StatefulWidget {
  const GeneratingCodeDialog({
    required this.stream,
    this.smaller = false,
    super.key,
  });

  final Stream<String> stream;
  final bool smaller;

  @override
  State<GeneratingCodeDialog> createState() => _GeneratingCodeDialogState();
}

class _GeneratingCodeDialogState extends State<GeneratingCodeDialog> {
  final _generatedCode = StringBuffer();
  bool _done = false;

  @override
  void initState() {
    super.initState();

    widget.stream.listen(
      (text) => setState(() => _generatedCode.write(text)),
      onDone: () => setState(() {
        final source = _generatedCode.toString().trim();
        _generatedCode.clear();
        _generatedCode.write(source);
        _done = true;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.smaller ? 500.0 : 700.0;
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text('Generating Code'),
        contentTextStyle: theme.textTheme.bodyMedium,
        contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
        content: SizedBox(
          width: width,
          // TODO: enable diff mode to show the changes
          child: ReadOnlyEditorWidget(_generatedCode.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _done
                ? () => Navigator.pop(context, _generatedCode.toString())
                : null,
            child: Text(
              'Accept',
              style: TextStyle(
                color: _done ? null : theme.disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
