// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../main.dart';
import '../model.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class GeminiCodeEditMenu extends StatelessWidget {
  final Map<AppType, Map<String, String>> promptSuggestions;
  final AppType currentAppType;
  final void Function(String) handlePromptSuggestion;
  final void Function() onAddImage;

  const GeminiCodeEditMenu({
    super.key,
    required this.currentAppType,
    required this.handlePromptSuggestion,
    required this.onAddImage,

    this.promptSuggestions = const {
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
    },
  });

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
      leadingIcon: PromptSuggestionIcon(),
      onPressed: handlePromptSuggestion,
      child: Padding(
        padding: EdgeInsets.only(right: 32),
        child: Text(displayName),
      ),
    );
  }
}

class PromptSuggestionIcon extends StatelessWidget {
  const PromptSuggestionIcon({super.key, this.height = 18, this.width = 18});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Opacity(
          opacity: 0.75,
          child: Image.asset(
            'prompt_suggestion_icon_lightmode.png',
            height: height,
            width: width,
          ),
        )
        : Image.asset(
          'prompt_suggestion_icon_darkmode.png',
          height: height,
          width: width,
        );
  }
}

class GeminiEditPrefixIcon extends StatelessWidget {
  const GeminiEditPrefixIcon({
    super.key,
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
              ? GeminiCodeEditMenu(
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

class GeminiEditSuffixIcon extends StatelessWidget {
  const GeminiEditSuffixIcon({
    super.key,
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
    final images = genAiManager.codeEditAttachments;

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
                        attachments: images,
                        prompt: promptController,
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
                  prefixIcon: GeminiEditPrefixIcon(
                    enabled: widget.enabled,
                    textFieldIsFocused: _textInputIsFocused,
                    handlePromptSuggestion: handlePromptSuggestion,
                    appType: appType,
                    onAddImage: () async {
                      await addAttachmentWithPicker(images);
                      setState(() {});
                    },
                  ),
                  suffixIcon: GeminiEditSuffixIcon(
                    textFieldIsFocused: _textInputIsFocused,
                    onGenerate: () {
                      widget.onUpdateCode(
                        context,
                        PromptDialogResponse(
                          appType: appType,
                          attachments: images,
                          prompt: promptController,
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
            if (images.isNotEmpty)
              SizedBox(
                height: 32,
                child: EditableImageList(
                  compactDisplay: true,
                  attachments: images,
                  onRemove: (int index) {
                    images.removeAt(index);
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
        final GeminiMessageTextTheme = TextStyle(
          color: Color.fromARGB(255, 60, 60, 60),
        );
        // TODO(alsobrian) 3/11/25: ExpectNever?
        final resolvedStatusMessage =
            genAiState == GenAiState.generating
                ? Text('Generating your code', style: GeminiMessageTextTheme)
                : Text(
                  'Gemini proposed the above',
                  style: GeminiMessageTextTheme,
                );
        final resolvedButtons =
            genAiState == GenAiState.generating
                ? [
                  TextButton(
                    onPressed: widget.onCancelUpdateCode,
                    child: Text('Cancel', style: GeminiMessageTextTheme),
                  ),
                ]
                : [
                  TextButton(
                    onPressed: widget.onRejectSuggestedCode,
                    child: Text('Cancel', style: GeminiMessageTextTheme),
                  ),
                  OutlinedButton(
                    onPressed: widget.onEditUpdateCodePrompt,
                    child: Text('Change Prompt', style: GeminiMessageTextTheme),
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
