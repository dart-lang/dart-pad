// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'editor/editor.dart';
import 'model.dart';
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
  const ReloadButton({super.key, super.onPressed})
    : super(
        text: 'Reload',
        icon: const Icon(Icons.flash_on, color: Colors.black, size: 20),
        tooltip:
            'Apply the changes with the hot reload mechanism, '
            'that rerenders the modified widgets, without losing the state.',
      );
}

abstract class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Icon icon;
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
      'idx' => 'assets/idx_192.png',
      _ => 'assets/dart_logo_192.png',
    };
    return Image.asset(assetPath, width: width);
  }
}

bool get _nonMac => defaultTargetPlatform != TargetPlatform.macOS;
bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

class PromptDialog extends StatefulWidget {
  const PromptDialog({
    required this.title,
    required this.hint,
    required this.flutterPromptButtons,
    required this.dartPromptButtons,
    required this.initialAppType,
    super.key,
  });

  final String title;
  final String hint;
  final Map<String, String> flutterPromptButtons;
  final Map<String, String> dartPromptButtons;
  final AppType initialAppType;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  final _controller = TextEditingController();
  final _attachments = List<Attachment>.empty(growable: true);
  final _focusNode = FocusNode();
  late AppType _appType;

  @override
  void initState() {
    super.initState();
    _appType = widget.initialAppType;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        title: Text(widget.title),
        contentTextStyle: theme.textTheme.bodyMedium,
        contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
        content: SizedBox(
          width: 700,
          child: CallbackShortcuts(
            bindings: {
              SingleActivator(
                LogicalKeyboardKey.enter,
                meta: _mac,
                control: _nonMac,
              ): () {
                if (_controller.text.isNotEmpty) _onGenerate();
              },
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OverflowBar(
                        spacing: 8,
                        alignment: MainAxisAlignment.start,
                        children: [
                          for (final entry
                              in _appType == AppType.flutter
                                  ? widget.flutterPromptButtons.entries
                                  : widget.dartPromptButtons.entries)
                            TextButton(
                              onPressed: () {
                                _controller.text = entry.value;
                                _focusNode.requestFocus();
                              },
                              child: Text(entry.key),
                            ),
                        ],
                      ),
                    ),
                    SegmentedButton<AppType>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<AppType>(
                          value: AppType.dart,
                          label: Text('Dart'),
                          tooltip: 'Generate Dart code',
                        ),
                        ButtonSegment<AppType>(
                          value: AppType.flutter,
                          label: Text('Flutter'),
                          tooltip: 'Generate Flutter code',
                        ),
                      ],
                      selected: {_appType},
                      onSelectionChanged: (selected) {
                        setState(() => _appType = selected.first);
                        _focusNode.requestFocus();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.hint,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 128,
                  child: EditableImageList(
                    attachments: _attachments,
                    onRemove: _removeAttachment,
                    onAdd: _addAttachment,
                    maxAttachments: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder:
                (context, controller, _) => TextButton(
                  onPressed: controller.text.isEmpty ? null : _onGenerate,
                  child: Text(
                    'Generate',
                    style: TextStyle(
                      color:
                          controller.text.isEmpty ? theme.disabledColor : null,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _onGenerate() {
    assert(_controller.text.isNotEmpty);
    Navigator.pop(
      context,
      PromptDialogResponse(
        appType: _appType,
        prompt: _controller.text,
        attachments: _attachments,
      ),
    );
  }

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  Future<void> _addAttachment() async {
    final pic = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pic == null) return;

    final bytes = await pic.readAsBytes();
    setState(
      () => _attachments.add(
        Attachment.fromBytes(
          name: pic.name,
          bytes: bytes,
          mimeType: pic.mimeType ?? lookupMimeType(pic.name) ?? 'image',
        ),
      ),
    );
  }
}

class GeneratingCodeDialog extends StatefulWidget {
  const GeneratingCodeDialog({
    required this.stream,
    required this.title,
    this.existingSource,
    super.key,
  });

  final Stream<String> stream;
  final String title;
  final String? existingSource;
  @override
  State<GeneratingCodeDialog> createState() => _GeneratingCodeDialogState();
}

class _GeneratingCodeDialogState extends State<GeneratingCodeDialog> {
  final _generatedCode = StringBuffer();
  final _focusNode = FocusNode();
  bool _done = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.stream.listen(
      (text) => setState(() => _generatedCode.write(text)),
      onDone:
          () => setState(() {
            final source = _generatedCode.toString().trim();
            _generatedCode.clear();
            _generatedCode.write(source);
            _done = true;
            _focusNode.requestFocus();
          }),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(
            LogicalKeyboardKey.enter,
            meta: _mac,
            control: _nonMac,
          ): () {
            if (_done) _onAcceptAndRun();
          },
        },
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title),
              if (!_done) const CircularProgressIndicator(),
            ],
          ),
          contentTextStyle: theme.textTheme.bodyMedium,
          contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
          content: SizedBox(
            width: 700,
            child: Focus(
              autofocus: true,
              focusNode: _focusNode,
              child:
                  widget.existingSource == null
                      ? ReadOnlyCodeWidget(_generatedCode.toString())
                      : ReadOnlyDiffWidget(
                        existingSource: widget.existingSource!,
                        newSource: _generatedCode.toString(),
                      ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        text: 'Powered by ',
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: 'Google AI',
                            style: TextStyle(color: theme.colorScheme.primary),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    url_launcher.launchUrl(
                                      Uri.parse('https://ai.google.dev/'),
                                    );
                                  },
                          ),
                          TextSpan(
                            text: ' and the Gemini API',
                            style: DefaultTextStyle.of(context).style,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _done ? _onAcceptAndRun : null,
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      color: !_done ? theme.disabledColor : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onAcceptAndRun() {
    assert(_done);
    Navigator.pop(context, _generatedCode.toString());
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
