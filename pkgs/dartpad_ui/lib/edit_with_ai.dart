// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import 'docs.dart';
import 'editor/editor.dart';
import 'editor/generating_panel.dart';
import 'extensions.dart';
import 'model.dart';
import 'problems.dart';
import 'prompt_dialog.dart';
import 'simple_widgets.dart';
import 'theme.dart';
import 'utils.dart';

class EditorWithButtons extends StatelessWidget {
  const EditorWithButtons({
    super.key,
    required this.appModel,
    required this.appServices,
    required this.onFormat,
    required this.onCompileAndRun,
    required this.onCompileAndReload,
  });

  final AppModel appModel;
  final AppServices appServices;
  final VoidCallback onFormat;
  final VoidCallback onCompileAndRun;
  final VoidCallback onCompileAndReload;

  Future<void> _requestGeminiCodeUpdate(
    BuildContext context,
    PromptDialogResponse promptInfo,
  ) async {
    appModel.genAiManager.preGenAiSourceCode.value =
        appModel.sourceCodeController.text;
    appModel.genAiManager.enterGeneratingEdit();
    try {
      final source = appModel.sourceCodeController.text;
      appModel.genAiManager.startStream(
        appServices.updateCode(
          UpdateCodeRequest(
            appType: promptInfo.appType,
            source: source,
            prompt: promptInfo.prompt,
            attachments: promptInfo.attachments,
          ),
        ),
      );
    } catch (error) {
      appModel.editorStatus.showToast('Error updating code');
      appModel.appendError('Updating code issue: $error');
      appModel.genAiManager.enterStandby();
    }
  }

  void _handleAcceptUpdateCode() {
    assert(appModel.genAiManager.streamIsDone.value);
    appModel.genAiManager.resetInputs();
    appModel.genAiManager.enterStandby();
  }

  void _handleEditUpdateCodePrompt(BuildContext context) async {
    appModel.sourceCodeController.textNoScroll =
        appModel.genAiManager.preGenAiSourceCode.value;
    appServices.performCompileAndReloadOrRun();
    appModel.genAiManager.enterStandby();
    openCodeGenerationDialog(context, changeLastPrompt: true);
  }

  void _handleCancelUpdateCode() {
    appModel.genAiManager.resetInputs();
    appModel.genAiManager.enterStandby();
  }

  void _handleRejectSuggestedCode() {
    appModel.genAiManager.resetInputs();
    appModel.genAiManager.enterStandby();
    appModel.sourceCodeController.textNoScroll =
        appModel.genAiManager.preGenAiSourceCode.value;
    appServices.performCompileAndReloadOrRun();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GenAiState>(
      valueListenable: appModel.genAiManager.currentState,
      builder: (BuildContext context, GenAiState genAiState, Widget? child) {
        return Column(
          children: [
            Expanded(
              child: SectionWidget(
                child: Stack(
                  children: [
                    if (genAiState == GenAiState.standby) ...[
                      EditorWidget(
                        appModel: appModel,
                        appServices: appServices,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: denseSpacing,
                        horizontal: defaultSpacing,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        // We use explicit directionality here in order to have the
                        // format and run buttons on the right hand side of the
                        // editing area.
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dartdoc help button
                          ValueListenableBuilder<bool>(
                            valueListenable: appModel.docHelpBusy,
                            builder: (_, bool value, __) {
                              return PointerInterceptor(
                                child: MiniIconButton(
                                  icon: const Icon(Icons.help_outline),
                                  tooltip: 'Show docs',
                                  // small: true,
                                  onPressed:
                                      value ? null : () => _showDocs(context),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: denseSpacing),
                          // Format action
                          ValueListenableBuilder<bool>(
                            valueListenable: appModel.formattingBusy,
                            builder: (_, bool value, __) {
                              return PointerInterceptor(
                                child: MiniIconButton(
                                  icon: const Icon(Icons.format_align_left),
                                  tooltip: 'Format',
                                  small: true,
                                  onPressed: value ? null : onFormat,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: defaultSpacing),
                          // Run action
                          ValueListenableBuilder(
                            valueListenable: appModel.showReload,
                            builder: (_, bool value, __) {
                              if (!value) return const SizedBox();
                              return ValueListenableBuilder<bool>(
                                valueListenable: appModel.canReload,
                                builder: (_, bool value, __) {
                                  return PointerInterceptor(
                                    child: ReloadButton(
                                      onPressed:
                                          value ? onCompileAndReload : null,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: defaultSpacing),
                          // Run action
                          ValueListenableBuilder<CompilingState>(
                            valueListenable: appModel.compilingState,
                            builder: (_, compiling, __) {
                              return PointerInterceptor(
                                child: RunButton(
                                  onPressed:
                                      compiling.busy ? null : onCompileAndRun,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.all(denseSpacing),
                      child: StatusWidget(status: appModel.editorStatus),
                    ),

                    if (genAiState == GenAiState.standby) ...[
                      SizedBox(width: 0, height: 0),
                    ] else ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.all(denseSpacing),
                        child: GeneratingCodePanel(
                          appModel: appModel,
                          appServices: appServices,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _GeminiCodeEditTool(
              appModel: appModel,
              enabled: appModel.genAiManager.state.value == GenAiState.standby,
              onUpdateCode: _requestGeminiCodeUpdate,
              onAcceptUpdateCode: _handleAcceptUpdateCode,
              onCancelUpdateCode: _handleCancelUpdateCode,
              onEditUpdateCodePrompt: _handleEditUpdateCodePrompt,
              onRejectSuggestedCode: _handleRejectSuggestedCode,
            ),
            MultiValueListenableBuilder(
              listenables: [
                appModel.analysisIssues,
                appModel.genAiManager.state,
              ],
              builder: (_) {
                if (genAiState != GenAiState.awaitingAcceptReject &&
                    genAiState != GenAiState.generating) {
                  return ProblemsTableWidget(
                    problems: appModel.analysisIssues.value,
                  );
                }
                return SizedBox(width: 0, height: 0);
              },
            ),
          ],
        );
      },
    );
  }

  static final RegExp _identifierChar = RegExp(r'[\w\d_<=>]');

  void _showDocs(BuildContext context) async {
    try {
      final source = appModel.sourceCodeController.text;
      final offset = appServices.editorService?.cursorOffset ?? -1;

      var valid = true;
      if (offset < 0 || offset >= source.length) {
        valid = false;
      } else {
        valid = _identifierChar.hasMatch(source.substring(offset, offset + 1));
      }

      if (!valid) {
        appModel.editorStatus.showToast('No docs at location.');
        return;
      }

      final result = await appServices.document(
        SourceRequest(source: source, offset: offset),
      );

      if (result.elementKind == null) {
        appModel.editorStatus.showToast('No docs at location.');
        return;
      } else if (context.mounted) {
        // show result

        showDialog<void>(
          context: context,
          builder: (context) {
            const longTitle = 40;

            var title = result.cleanedUpTitle ?? 'Dartdoc';
            if (title.length > longTitle) {
              title = '${title.substring(0, longTitle)}…';
            }
            return MediumDialog(
              title: title,
              child: DocsWidget(appModel: appModel, documentResponse: result),
            );
          },
        );
      }

      appServices.editorService!.focus();
    } catch (error) {
      appModel.editorStatus.showToast('Error retrieving docs');
      appModel.appendError('$error');
      return;
    }
  }
}

class _GeminiCodeEditTool extends StatefulWidget {
  const _GeminiCodeEditTool({
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
  final void Function(BuildContext context) onEditUpdateCodePrompt;
  final VoidCallback onAcceptUpdateCode;
  final VoidCallback onRejectSuggestedCode;
  final bool enabled;

  @override
  State<_GeminiCodeEditTool> createState() => _GeminiCodeEditToolState();
}

class _GeminiCodeEditToolState extends State<_GeminiCodeEditTool> {
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

    final appModel = Provider.of<AppModel>(context, listen: false);

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

                  if (appModel.genAiManager.activeCuj.value !=
                      GenAiCuj.suggestFix)
                    OutlinedButton(
                      onPressed: () => widget.onEditUpdateCodePrompt(context),
                      child: Text(
                        'Change Prompt',
                        style: geminiMessageTextTheme,
                      ),
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
      leadingIcon: PromptSuggestionIcon(),
      onPressed: handlePromptSuggestion,
      child: Padding(
        padding: EdgeInsets.only(right: 32),
        child: Text(displayName),
      ),
    );
  }
}
