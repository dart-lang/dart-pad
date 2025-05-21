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
import 'genai_dialogs.dart';
import 'model.dart';
import 'problems.dart';
import 'simple_widgets.dart';
import 'theme.dart';
import 'utils.dart';

class EditorWithButtons extends StatefulWidget {
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
  @override
  State<EditorWithButtons> createState() => _EditorWithButtonsState();

  static final RegExp _identifierChar = RegExp(r'[\w\d_<=>]');
}

class _EditorWithButtonsState extends State<EditorWithButtons> {
  final _changePromptFocusNode = FocusNode();

  @override
  void dispose() {
    _changePromptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestGeminiCodeUpdate(
    BuildContext context,
    PromptDialogResponse promptInfo,
  ) async {
    widget.appModel.genAiManager.preGenAiSourceCode.value =
        widget.appModel.sourceCodeController.text;
    widget.appModel.genAiManager.enterGeneratingEdit();
    try {
      final source = widget.appModel.sourceCodeController.text;
      widget.appModel.genAiManager.startStream(
        widget.appServices.updateCode(
          UpdateCodeRequest(
            appType: promptInfo.appType,
            source: source,
            prompt: promptInfo.prompt,
            attachments: promptInfo.attachments,
          ),
        ),
      );
    } catch (error) {
      widget.appModel.editorStatus.showToast('Error updating code');
      widget.appModel.appendError('Updating code issue: $error');
      widget.appModel.genAiManager.finishActivity();
    }
  }

  void _handleAcceptUpdateCode() {
    assert(widget.appModel.genAiManager.streamIsDone.value);
    widget.appModel.genAiManager.resetState();
  }

  void _handleEditUpdateCodePrompt(BuildContext context) async {
    widget.appModel.sourceCodeController.textNoScroll =
        widget.appModel.genAiManager.preGenAiSourceCode.value;
    widget.appServices.performCompileAndReloadOrRun();
    widget.appModel.genAiManager.finishActivity();

    final activeCuj = widget.appModel.genAiManager.cuj.value;

    if (activeCuj == GenAiCuj.generateCode) {
      openCodeGenerationDialog(context, reuseLastPrompt: true);
    } else {
      // See https://stackoverflow.com/questions/56221653/focusnode-why-is-requestfocus-not-working
      Future.delayed(Duration(milliseconds: 50), () {
        _changePromptFocusNode.requestFocus();
      });
    }
  }

  void _handleCancelUpdateCode() {
    widget.appModel.genAiManager.resetState();
  }

  void _handleRejectSuggestedCode() {
    widget.appModel.genAiManager.resetState();
    widget.appModel.sourceCodeController.textNoScroll =
        widget.appModel.genAiManager.preGenAiSourceCode.value;
    widget.appServices.performCompileAndReloadOrRun();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GenAiActivity?>(
      valueListenable: widget.appModel.genAiManager.currentActivity,
      builder: (
        BuildContext context,
        GenAiActivity? genAiActivity,
        Widget? child,
      ) {
        return Column(
          children: [
            Expanded(
              child: SectionWidget(
                child: Stack(
                  children: [
                    if (genAiActivity == null)
                      EditorWidget(
                        appModel: widget.appModel,
                        appServices: widget.appServices,
                      ),
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
                            valueListenable: widget.appModel.docHelpBusy,
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
                            valueListenable: widget.appModel.formattingBusy,
                            builder: (_, bool value, __) {
                              return PointerInterceptor(
                                child: MiniIconButton(
                                  icon: const Icon(Icons.format_align_left),
                                  tooltip: 'Format',
                                  small: true,
                                  onPressed: value ? null : widget.onFormat,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: defaultSpacing),
                          // Run action
                          ValueListenableBuilder(
                            valueListenable: widget.appModel.showReload,
                            builder: (_, bool value, __) {
                              if (!value) return const SizedBox();
                              return ValueListenableBuilder<bool>(
                                valueListenable: widget.appModel.canReload,
                                builder: (_, bool value, __) {
                                  return PointerInterceptor(
                                    child: ReloadButton(
                                      onPressed:
                                          value
                                              ? widget.onCompileAndReload
                                              : null,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: defaultSpacing),
                          // Run action
                          ValueListenableBuilder<CompilingState>(
                            valueListenable: widget.appModel.compilingState,
                            builder: (_, compiling, __) {
                              return PointerInterceptor(
                                child: RunButton(
                                  onPressed:
                                      compiling.busy
                                          ? null
                                          : widget.onCompileAndRun,
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
                      child: StatusWidget(status: widget.appModel.editorStatus),
                    ),

                    if (genAiActivity == null)
                      SizedBox(width: 0, height: 0)
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.all(denseSpacing),
                        child: GeneratingCodePanel(
                          appModel: widget.appModel,
                          appServices: widget.appServices,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _GeminiCodeEditTool(
              appModel: widget.appModel,
              enabled: widget.appModel.genAiManager.activity.value == null,
              onUpdateCode: _requestGeminiCodeUpdate,
              onAcceptUpdateCode: _handleAcceptUpdateCode,
              onCancelUpdateCode: _handleCancelUpdateCode,
              onEditUpdateCodePrompt: _handleEditUpdateCodePrompt,
              onRejectSuggestedCode: _handleRejectSuggestedCode,
              changePromptFocusNode: _changePromptFocusNode,
            ),
            MultiValueListenableBuilder(
              listenables: [
                widget.appModel.analysisIssues,
                widget.appModel.genAiManager.activity,
              ],
              builder: (_) {
                if (genAiActivity != GenAiActivity.awaitingAcceptance &&
                    genAiActivity != GenAiActivity.generating) {
                  return ProblemsTableWidget(
                    problems: widget.appModel.analysisIssues.value,
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

  void _showDocs(BuildContext context) async {
    try {
      final source = widget.appModel.sourceCodeController.text;
      final offset = widget.appServices.editorService?.cursorOffset ?? -1;

      var valid = true;
      if (offset < 0 || offset >= source.length) {
        valid = false;
      } else {
        valid = EditorWithButtons._identifierChar.hasMatch(
          source.substring(offset, offset + 1),
        );
      }

      if (!valid) {
        widget.appModel.editorStatus.showToast('No docs at location.');
        return;
      }

      final result = await widget.appServices.document(
        SourceRequest(source: source, offset: offset),
      );

      if (result.elementKind == null) {
        widget.appModel.editorStatus.showToast('No docs at location.');
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
              child: DocsWidget(
                appModel: widget.appModel,
                documentResponse: result,
              ),
            );
          },
        );
      }

      widget.appServices.editorService!.focus();
    } catch (error) {
      widget.appModel.editorStatus.showToast('Error retrieving docs');
      widget.appModel.appendError('$error');
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
    required this.changePromptFocusNode,
  });

  final AppModel appModel;
  final Future<void> Function(BuildContext, PromptDialogResponse) onUpdateCode;

  final void Function(BuildContext context) onEditUpdateCodePrompt;
  final VoidCallback onRejectSuggestedCode;
  final VoidCallback onCancelUpdateCode;
  final VoidCallback onAcceptUpdateCode;

  final FocusNode changePromptFocusNode;

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
                SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: isMac,
                  control: isNonMac,
                ): () {
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
                focusNode: widget.changePromptFocusNode,
                canRequestFocus: true,
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

    return Column(
      children: [
        _AcceptRejectBlock(
          genAiManager,
          onCancelUpdateCode: widget.onCancelUpdateCode,
          onAcceptUpdateCode: widget.onAcceptUpdateCode,
          onEditUpdateCodePrompt: widget.onEditUpdateCodePrompt,
          onRejectSuggestedCode: widget.onRejectSuggestedCode,
        ),
        textInputBlock,
      ],
    );
  }
}

const geminiMessageTextTheme = TextStyle(
  color: Color.fromARGB(255, 60, 60, 60),
);

class _AcceptRejectBlock extends StatelessWidget {
  const _AcceptRejectBlock(
    this.genAiManager, {
    required this.onCancelUpdateCode,
    required this.onAcceptUpdateCode,
    required this.onEditUpdateCodePrompt,
    required this.onRejectSuggestedCode,
  });

  final GenAiManager genAiManager;
  final VoidCallback onCancelUpdateCode;
  final VoidCallback onAcceptUpdateCode;
  final void Function(BuildContext context) onEditUpdateCodePrompt;
  final VoidCallback onRejectSuggestedCode;

  static String _statusMessage(BuildContext context, GenAiActivity genAiState) {
    final size = MediaQuery.of(context).size;
    if (size.width < 1150) return '';

    return genAiState == GenAiActivity.generating
        ? 'Generating your code'
        : 'Gemini proposed the above';
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: false);

    return ValueListenableBuilder<GenAiActivity?>(
      valueListenable: genAiManager.currentActivity,
      builder: (
        BuildContext context,
        GenAiActivity? genAiActivity,
        Widget? child,
      ) {
        if (genAiActivity == null) return SizedBox(width: 0, height: 0);

        final geminiIcon = Image.asset(
          'assets/gemini_sparkle_192.png',
          width: 16,
          height: 16,
        );

        final activeCuj = appModel.genAiManager.cuj.value;

        final resolvedButtons =
            genAiActivity == GenAiActivity.generating
                ? [
                  TextButton(
                    onPressed: onCancelUpdateCode,
                    child: Text('Cancel', style: geminiMessageTextTheme),
                  ),
                ]
                : [
                  TextButton(
                    onPressed: onRejectSuggestedCode,
                    child: Text('Cancel', style: geminiMessageTextTheme),
                  ),

                  if (activeCuj != GenAiCuj.suggestFix)
                    _ChangePromptBtn(() => onEditUpdateCodePrompt(context)),

                  FilledButton(
                    onPressed: onAcceptUpdateCode,
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
                    Text(
                      _statusMessage(context, genAiActivity),
                      style: geminiMessageTextTheme,
                    ),
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
        SizedBox(width: textFieldIsFocused ? 4 : 5),
      ],
    );
  }
}

class _ChangePromptBtn extends StatelessWidget {
  const _ChangePromptBtn(this.handler);

  final VoidCallback handler;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: handler,
      child: Text('Change Prompt', style: geminiMessageTextTheme),
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
            onPressed: () => menuController.toggle(),
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
