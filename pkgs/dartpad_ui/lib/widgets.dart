// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'editor/editor.dart';
// import 'main.dart';
import 'extensions.dart';
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

class PromptDialog extends StatefulWidget {
  const PromptDialog({
    required this.title,
    required this.hint,
    required this.flutterPromptButtons,
    required this.dartPromptButtons,
    required this.initialAppType,
    required this.promptTextController,
    required this.attachments,
    super.key,
  });

  final String title;
  final String hint;
  final Map<String, String> flutterPromptButtons;
  final Map<String, String> dartPromptButtons;
  final AppType initialAppType;
  final TextEditingController promptTextController;
  final List<Attachment> attachments;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
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
              SingleActivator(LogicalKeyboardKey.enter): () {
                if (widget.promptTextController.text.isNotEmpty) _onGenerate();
              },
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: widget.promptTextController,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: Theme.of(context).hintColor),
                    labelText: 'Code generation prompt',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OverflowBar(
                        alignment: MainAxisAlignment.center,
                        spacing: 12,
                        children: [
                          for (final entry
                              in widget.initialAppType == AppType.flutter
                                  ? widget.flutterPromptButtons.entries
                                  : widget.dartPromptButtons.entries)
                            OutlinedButton.icon(
                              icon: _PromptSuggestionIcon(),
                              onPressed: () {
                                widget.promptTextController.text = entry.value;
                                _focusNode.requestFocus();
                              },
                              label: Text(entry.key),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 64,
                  child: EditableImageList(
                    attachments: widget.attachments,
                    onRemove: (int index) {
                      widget.attachments.removeAt(index);
                      setState(() {});
                    },
                    onAdd: () async {
                      await addAttachmentWithPicker(widget.attachments);
                      setState(() {});
                    },
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
            valueListenable: widget.promptTextController,
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
    assert(widget.promptTextController.text.isNotEmpty);
    Navigator.pop(
      context,
      PromptDialogResponse(
        appType: widget.initialAppType,
        attachments: widget.attachments,
        prompt: widget.promptTextController.text,
      ),
    );
  }
}

class GeneratingCodePanel extends StatefulWidget {
  const GeneratingCodePanel({
    required this.appModel,
    required this.appServices,
    super.key,
  });

  final AppModel appModel;
  final AppServices appServices;

  @override
  State<GeneratingCodePanel> createState() => _GeneratingCodePanelState();
}

class _GeneratingCodePanelState extends State<GeneratingCodePanel> {
  final _focusNode = FocusNode();
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();

    final genAiManager = widget.appModel.genAiManager;

    final stream = genAiManager.stream;

    _subscription = stream.value.listen(
      (text) => setState(() {
        genAiManager.writeToStreamBuffer(text);
      }),
      onDone: () {
        setState(() {
          final generatedCode = genAiManager.generatedCode().trim();
          if (generatedCode.isEmpty) {
            widget.appModel.editorStatus.showToast('Error generating code');
            widget.appModel.appendError(
              'There was an error generating your code, please try again.',
            );
            widget.appModel.genAiManager.enterStandby();
            return;
          }
          genAiManager.setStreamBufferValue(generatedCode);
          genAiManager.setStreamIsDone(true);
          genAiManager.enterAwaitingAcceptReject();
          _focusNode.requestFocus();
          widget.appModel.sourceCodeController.textNoScroll = generatedCode;
          widget.appServices.performCompileAndRun();
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genAiManager = widget.appModel.genAiManager;
    return ValueListenableBuilder(
      valueListenable: genAiManager.streamIsDone,
      builder: (
        BuildContext context,
        bool genAiCodeStreamIsDone,
        Widget? child,
      ) {
        final resolvedSpinner =
            genAiCodeStreamIsDone
                ? SizedBox(width: 0, height: 0)
                : Positioned(
                  top: 10,
                  right: 10,
                  child: AnimatedContainer(
                    duration: animationDelay,
                    curve: animationCurve,
                    child: CircularProgressIndicator(),
                  ),
                );
        return Stack(
          children: [
            resolvedSpinner,
            ValueListenableBuilder(
              valueListenable: genAiManager.streamBuffer,
              builder: (
                BuildContext context,
                StringBuffer genAiCodeStreamBuffer,
                Widget? child,
              ) {
                return Focus(
                  autofocus: true,
                  focusNode: _focusNode,
                  child: ValueListenableBuilder(
                    valueListenable:
                        widget.appModel.genAiManager.isGeneratingNewProject,
                    builder: (
                      BuildContext context,
                      bool genAiGeneratingNewProject,
                      Widget? child,
                    ) {
                      return ValueListenableBuilder(
                        valueListenable: genAiManager.preGenAiSourceCode,
                        builder: (
                          BuildContext context,
                          String existingSource,
                          Widget? child,
                        ) {
                          return genAiGeneratingNewProject
                              ? ReadOnlyCodeWidget(
                                genAiCodeStreamBuffer.toString(),
                              )
                              : ReadOnlyDiffWidget(
                                existingSource: existingSource,
                                newSource: genAiCodeStreamBuffer.toString(),
                              );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class EditableImageList extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(int index) onRemove;
  final void Function() onAdd;
  final int maxAttachments;
  final bool compactDisplay;

  const EditableImageList({
    super.key,
    required this.attachments,
    required this.onRemove,
    required this.onAdd,
    required this.maxAttachments,
    this.compactDisplay = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      // First item is the "Add Attachment" button
      itemCount: attachments.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (compactDisplay) {
            return SizedBox(height: 0, width: 0);
          }
          return _AddImageWidget(
            onAdd: attachments.length < maxAttachments ? onAdd : null,
            hasAttachments: attachments.isNotEmpty,
          );
        } else {
          final attachmentIndex = index - 1;
          return _ImageAttachmentWidget(
            attachment: attachments[attachmentIndex],
            onRemove: () => onRemove(attachmentIndex),
            compactDisplay: compactDisplay,
          );
        }
      },
    );
  }
}

class _ImageAttachmentWidget extends StatelessWidget {
  final Attachment attachment;
  final void Function() onRemove;
  final bool compactDisplay;

  const _ImageAttachmentWidget({
    required this.attachment,
    required this.onRemove,
    required this.compactDisplay,
  });

  final double regularThumbnailSize = 64;
  final double compactThumbnailSize = 32;

  @override
  Widget build(BuildContext context) {
    final resolvedThumbnailEdgeInsets =
        compactDisplay ? EdgeInsets.fromLTRB(0, 4, 4, 0) : EdgeInsets.all(8);
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
            margin: resolvedThumbnailEdgeInsets,
            width: compactDisplay ? compactThumbnailSize : regularThumbnailSize,
            height:
                compactDisplay ? compactThumbnailSize : regularThumbnailSize,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: MemoryImage(attachment.bytes),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: compactDisplay ? 2 : 4,
          right: compactDisplay ? 2 : 4,
          child: Transform.scale(
            scale: compactDisplay ? 0.7 : 1,
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
        ),
      ],
    );
  }
}

class _AddImageWidget extends StatelessWidget {
  final void Function()? onAdd;
  final bool hasAttachments;
  const _AddImageWidget({required this.onAdd, required this.hasAttachments});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filledTonal(
            icon: Icon(Icons.add),
            onPressed: onAdd,
          ),
        ),
        if (!hasAttachments)
          Text('Add image(s) to support your prompt. (optional)'),
      ],
    );
  }
}

class _PromptSuggestionIcon extends StatelessWidget {
  const _PromptSuggestionIcon();

  @override
  Widget build(BuildContext context) {
    const height = 18.0;
    const width = 18.0;

    return Theme.of(context).brightness == Brightness.light
        ? Opacity(
          opacity: 0.75,
          child: Image.asset(
            'assets/prompt_suggestion_icon_lightmode.png',
            height: height,
            width: width,
          ),
        )
        : Image.asset(
          'assets/prompt_suggestion_icon_darkmode.png',
          height: height,
          width: width,
        );
  }
}

class GeminiCodeEditTool extends StatefulWidget {
  const GeminiCodeEditTool({
    super.key,
    required this.appModel,
    required this.onUpdateCode,
    required this.onCancelUpdateCode,
    required this.onRejectSuggestedCode,
    required this.onEditUpdateCodePrompt,
    required this.onAcceptUpdateCode,
    required this.enabled,
  });

  final AppModel appModel;
  final Future<void> Function(BuildContext, PromptDialogResponse) onUpdateCode;
  final VoidCallback onCancelUpdateCode;
  final VoidCallback onEditUpdateCodePrompt;
  final VoidCallback onAcceptUpdateCode;
  final VoidCallback onRejectSuggestedCode;
  final bool enabled;

  @override
  State<GeminiCodeEditTool> createState() => _GeminiCodeEditToolState();
}

class _GeminiCodeEditToolState extends State<GeminiCodeEditTool> {
  bool _textInputIsFocused = false;
  late GenAiManager genAiManager;

  @override
  void initState() {
    super.initState();
    genAiManager = widget.appModel.genAiManager;
  }

  @override
  void dispose() {
    super.dispose();
  }

  AppType analyzedAppTypeFromSource(AppModel appModel) {
    if (appModel.sourceCodeController.text.contains(
      """import 'package:flutter""",
    )) {
      return AppType.flutter;
    }
    return AppType.dart;
  }

  void handlePromptSuggestion(String promptText) {
    genAiManager.setEditPromptText(promptText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appType = analyzedAppTypeFromSource(widget.appModel);
    final promptController = genAiManager.codeEditPromptController;
    final attachments = genAiManager.codeEditAttachments;

    final textInputBlock = Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: Divider.createBorderSide(
            context,
            width: 8.0,
            color: theme.colorScheme.surface,
          ),
        ),
      ),
      padding: const EdgeInsets.all(denseSpacing),
      child: Focus(
        onFocusChange:
            (value) => setState(() {
              _textInputIsFocused = value;
            }),
        child: Column(
          children: [
            CallbackShortcuts(
              bindings: {
                SingleActivator(LogicalKeyboardKey.enter): () {
                  if (promptController.text.isNotEmpty) {
                    widget.onUpdateCode(
                      context,
                      PromptDialogResponse(
                        appType: appType,
                        attachments: attachments,
                        prompt: promptController.text,
                      ),
                    );
                    setState(() {});
                  }
                },
              },
              child: TextField(
                enabled: widget.enabled,
                controller: promptController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                  hintText:
                      widget.enabled
                          ? 'Ask Gemini to change your code or app!'
                          : '',
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  prefixIcon: _GeminiEditPrefixIcon(
                    enabled: widget.enabled,
                    textFieldIsFocused: _textInputIsFocused,
                    handlePromptSuggestion: handlePromptSuggestion,
                    appType: appType,
                    onAddImage: () async {
                      await addAttachmentWithPicker(attachments);
                      setState(() {});
                    },
                  ),
                  suffixIcon: _GeminiEditSuffixIcon(
                    textFieldIsFocused: _textInputIsFocused,
                    onGenerate: () {
                      widget.onUpdateCode(
                        context,
                        PromptDialogResponse(
                          appType: appType,
                          attachments: attachments,
                          prompt: promptController.text,
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ),
                maxLines: 8,
                minLines: 1,
              ),
            ),
            if (attachments.isNotEmpty)
              SizedBox(
                height: 32,
                child: EditableImageList(
                  compactDisplay: true,
                  attachments: attachments,
                  onRemove: (int index) {
                    attachments.removeAt(index);
                    setState(() {});
                  },
                  onAdd: () => {}, // the Add button isn't shown here
                  maxAttachments: 3,
                ),
              ),
          ],
        ),
      ),
    );

    final acceptRejectBlock = ValueListenableBuilder<GenAiState>(
      valueListenable: genAiManager.currentState,
      builder: (BuildContext context, GenAiState genAiState, Widget? child) {
        if (genAiState == GenAiState.standby) {
          return SizedBox(width: 0, height: 0);
        }
        final geminiIcon = Image.asset(
          'assets/gemini_sparkle_192.png',
          width: 16,
          height: 16,
        );
        final geminiMessageTextTheme = TextStyle(
          color: Color.fromARGB(255, 60, 60, 60),
        );
        // TODO(alsobrian) 3/11/25: ExpectNever?
        final resolvedStatusMessage =
            genAiState == GenAiState.generating
                ? Text('Generating your code', style: geminiMessageTextTheme)
                : Text(
                  'Gemini proposed the above',
                  style: geminiMessageTextTheme,
                );
        final resolvedButtons =
            genAiState == GenAiState.generating
                ? [
                  TextButton(
                    onPressed: widget.onCancelUpdateCode,
                    child: Text('Cancel', style: geminiMessageTextTheme),
                  ),
                ]
                : [
                  TextButton(
                    onPressed: widget.onRejectSuggestedCode,
                    child: Text('Cancel', style: geminiMessageTextTheme),
                  ),
                  OutlinedButton(
                    onPressed: widget.onEditUpdateCodePrompt,
                    child: Text('Change Prompt', style: geminiMessageTextTheme),
                  ),
                  FilledButton(
                    onPressed: widget.onAcceptUpdateCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(0xff2e64de),
                    ),
                    child: Text(
                      'Accept',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ];
        return Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xFFD7E6FF),
                Color(0xFFC7E4FF),
                Color(0xFFDCE2FF),
                // Color(0xFF2E64De),
                // Color(0xFF3C8FE3),
                // Color(0xFF987BE9),
              ],
            ),
          ), //Color.fromRGBO(200, 230, 255, 1.0)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    geminiIcon,
                    SizedBox(width: 8),
                    resolvedStatusMessage,
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 8.0, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 12,
                      children: resolvedButtons,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return Column(children: [acceptRejectBlock, textInputBlock]);
  }
}

class _GeminiEditPrefixIcon extends StatelessWidget {
  const _GeminiEditPrefixIcon({
    required this.textFieldIsFocused,
    required this.appType,
    required this.handlePromptSuggestion,
    required this.onAddImage,
    required this.enabled,
  });

  final bool textFieldIsFocused;
  final AppType appType;
  final void Function(String) handlePromptSuggestion;
  final void Function() onAddImage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: textFieldIsFocused ? 12 : 8),
        ...[
          textFieldIsFocused
              ? _GeminiCodeEditMenu(
                currentAppType: appType,
                handlePromptSuggestion: handlePromptSuggestion,
                onAddImage: onAddImage,
              )
              : SizedBox(
                width: 29,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: enabled ? 1 : 0.45,
                    child: Image.asset(
                      'assets/gemini_sparkle_192.png',
                      fit: BoxFit.contain,
                      height: 24,
                      width: 24,
                    ),
                  ),
                ),
              ),
        ],
        SizedBox(width: textFieldIsFocused ? 4 : 5),
      ],
    );
  }
}

class _GeminiEditSuffixIcon extends StatelessWidget {
  const _GeminiEditSuffixIcon({
    required this.textFieldIsFocused,
    required this.onGenerate,
  });

  final bool textFieldIsFocused;
  final void Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child:
          textFieldIsFocused
              ? Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    padding: EdgeInsets.all(0),
                    onPressed: onGenerate,
                    icon: const Icon(Icons.send),
                    iconSize: 14,
                  ),
                ),
              )
              : null,
    );
  }
}

class _GeminiCodeEditMenu extends StatelessWidget {
  final AppType currentAppType;
  final void Function(String) handlePromptSuggestion;
  final void Function() onAddImage;

  const _GeminiCodeEditMenu({
    required this.currentAppType,
    required this.handlePromptSuggestion,
    required this.onAddImage,
  });

  final promptSuggestions = const {
    AppType.dart: {
      'pretty-dart': 'Make the app pretty',
      'fancy-dart': 'Make the app fancy',
      'emoji-dart': 'Make the app use emojis',
    },
    AppType.flutter: {
      'pretty':
          'Make the app pretty by improving the visual design - add proper spacing, consistent typography, a pleasing color scheme, and ensure the overall layout follows Material Design principles',
      'fancy':
          'Make the app fancy by adding rounded corners where appropriate, subtle shadows and animations for interactivity; make tasteful use of gradients and images',
      'emoji':
          'Make the app use emojis by adding appropriate emoji icons and text',
    },
  };

  @override
  Widget build(BuildContext context) {
    final List<Widget> resolvedPromptSuggestions =
        promptSuggestions[currentAppType]?.entries.map((entry) {
          final String promptName = entry.key;
          final String promptText = entry.value;
          return _GeminiCodeEditMenuPromptSuggestion(
            displayName: promptName,
            promptText: promptText,
            handlePromptSuggestion: () => handlePromptSuggestion(promptText),
          );
        }).toList() ??
        [];
    final List<Widget> resolvedMenuItems = [
      ...resolvedPromptSuggestions,
      MenuItemButton(
        leadingIcon: const Icon(Icons.image, size: 16),
        onPressed: onAddImage,
        child: Padding(
          padding: EdgeInsets.only(right: 32),
          child: Text('Add image'),
        ),
      ),
    ];

    return MenuAnchor(
      builder: (context, MenuController menuController, Widget? child) {
        return SizedBox(
          height: 26,
          width: 26,
          child: IconButton.filledTonal(
            onPressed: () => menuController.toggleMenuState(),
            padding: EdgeInsets.all(0.0),
            icon: const Icon(Icons.add),
            iconSize: 16,
          ),
        );
      },
      alignmentOffset: Offset(0, 10),
      menuChildren: [
        ...resolvedMenuItems.map((widget) => PointerInterceptor(child: widget)),
      ],
    );
  }
}

class _GeminiCodeEditMenuPromptSuggestion extends StatelessWidget {
  const _GeminiCodeEditMenuPromptSuggestion({
    required this.displayName,
    required this.promptText,
    required this.handlePromptSuggestion,
  });

  final String displayName;
  final String promptText;
  final VoidCallback handlePromptSuggestion;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: _PromptSuggestionIcon(),
      onPressed: handlePromptSuggestion,
      child: Padding(
        padding: EdgeInsets.only(right: 32),
        child: Text(displayName),
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
