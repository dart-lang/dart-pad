// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/model.dart';
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
    required this.hint,
    this.smaller = false,
    super.key,
  });

  final bool smaller;
  final String title;
  final String hint;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  final _controller = TextEditingController();
  final _attachments = List<Attachment>.empty(growable: true);

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
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  () {
                if (_controller.text.isNotEmpty) _onGenerate();
              },
              const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
                if (_controller.text.isNotEmpty) _onGenerate();
              },
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
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
            builder: (context, controller, _) => TextButton(
              onPressed: controller.text.isEmpty ? null : _onGenerate,
              child: Text(
                'Generate',
                style: TextStyle(
                  color: controller.text.isEmpty ? theme.disabledColor : null,
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
      PromptResponse(prompt: _controller.text, attachments: _attachments),
    );
  }

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  Future<void> _addAttachment() async {
    final pic = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

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
    this.smaller = false,
    super.key,
  });

  final Stream<String> stream;
  final bool smaller;
  final String title;
  @override
  State<GeneratingCodeDialog> createState() => _GeneratingCodeDialogState();
}

class _GeneratingCodeDialogState extends State<GeneratingCodeDialog> {
  final _generatedCode = StringBuffer();
  bool _done = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.stream.listen(
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
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.smaller ? 500.0 : 700.0;
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
            if (_done) _onAccept();
          },
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
            if (_done) _onAccept();
          },
        },
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title),
              if (!_done) const CircularProgressIndicator(),
            ],
          ),
          contentTextStyle: theme.textTheme.bodyMedium,
          contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
          content: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: width,
                  // TODO (csells): enable diff mode to show the changes
                  child: ReadOnlyEditorWidget(_generatedCode.toString()),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    text: 'Powered by ',
                    children: [
                      TextSpan(
                        text: 'Google AI',
                        style: const TextStyle(color: Colors.blue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            url_launcher.launchUrl(
                              Uri.parse('https://ai.google.dev/'),
                            );
                          },
                      ),
                      const TextSpan(text: ' and the Gemini API'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _done ? _onAccept : null,
              child: Text(
                'Accept',
                style: TextStyle(
                  color: !_done ? theme.disabledColor : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAccept() {
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
  Widget build(BuildContext context) => ListView.builder(
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

class _ImageAttachmentWidget extends StatelessWidget {
  final Attachment attachment;
  final void Function() onRemove;

  const _ImageAttachmentWidget({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Stack(
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
                message: 'Remove Image',
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

class _AddImageWidget extends StatelessWidget {
  final void Function()? onAdd;
  const _AddImageWidget({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
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
                    child: Text(
                      'Add\nImage',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
