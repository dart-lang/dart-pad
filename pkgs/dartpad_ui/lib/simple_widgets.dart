// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
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
  final Widget icon;
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
        icon: icon,
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
  ReloadButton({super.key, super.onPressed})
    : super(
        text: 'Reload',
        icon: ImageIcon(
          AssetImage('assets/hot-reload.png'),
          color: Colors.black,
        ),
        tooltip:
            'Apply changes with Hot Reload, which re-renders the modified'
            ' widgets without losing the state of the app, when possible.',
      );
}

abstract class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Widget icon;
  final String? tooltip;

  const ActionButton({
    this.onPressed,
    super.key,
    required this.text,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? text,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outline, width: 1),
            ),
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
      'firebase_studio' => 'assets/firebase_studio_192.png',
      _ => 'assets/dart_logo_192.png',
    };
    return Image.asset(assetPath, width: width);
  }
}

class EditableImageList extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(int index) onRemove;
  final void Function() onAdd;
  final int maxAttachments;

  const EditableImageList({
    super.key,
    required this.attachments,
    required this.onRemove,
    required this.onAdd,
    required this.maxAttachments,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      scrollDirection: Axis.horizontal,
      // First item is the "Add Attachment" button
      itemCount: attachments.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AddImageWidget(
            onAdd: attachments.length < maxAttachments ? onAdd : null,
          );
        } else {
          final attachmentIndex = index - 1;
          return _ImageAttachmentWidget(
            attachment: attachments[attachmentIndex],
            onRemove: () => onRemove(attachmentIndex),
          );
        }
      },
    );
  }
}

class _ImageAttachmentWidget extends StatelessWidget {
  final Attachment attachment;
  final void Function() onRemove;

  const _ImageAttachmentWidget({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(attachment.bytes),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: MemoryImage(attachment.bytes),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: InkWell(
            onTap: onRemove,
            child: Tooltip(
              message: 'Remove image',
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                radius: 12,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageWidget extends StatelessWidget {
  final void Function()? onAdd;
  const _AddImageWidget({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 128,
          height: 128,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.square(
              dimension: 128,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Center(
                  child: Text('Add\nimage', textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CollapsibleIconToggleButton extends StatelessWidget {
  const CollapsibleIconToggleButton({
    super.key,
    required this.onToggle,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.hideLabel = false,
    this.compact = false,
  });

  final void Function() onToggle;
  final Widget icon;
  final Text label;
  final String tooltip;
  final bool hideLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: tooltipDelay,
      child:
          hideLabel
              ? IconButton(
                icon: icon,
                onPressed: onToggle,
                visualDensity: compact ? VisualDensity.compact : null,
              )
              : TextButton.icon(icon: icon, label: label, onPressed: onToggle),
    );
  }
}

class SectionWidget extends StatelessWidget {
  final String? title;
  final Widget? actions;
  final Widget child;

  const SectionWidget({
    this.title,
    this.actions,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var finalChild = child;

    if (title != null || actions != null) {
      finalChild = Column(
        children: [
          Row(
            children: [
              if (title != null) Text(title!, style: subtleText),
              const Expanded(child: SizedBox(width: defaultSpacing)),
              if (actions != null) actions!,
            ],
          ),
          const Divider(),
          Expanded(child: child),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: finalChild,
    );
  }
}
