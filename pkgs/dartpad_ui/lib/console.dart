// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'enable_gen_ai.dart';
import 'model.dart';
import 'simple_widgets.dart';
import 'suggest_fix.dart';
import 'theme.dart';
import 'utils.dart';

class ConsoleWidget extends StatefulWidget {
  final bool showDivider;
  final ConsoleNotifier output;

  const ConsoleWidget({
    this.showDivider = false,
    required this.output,
    super.key,
  });

  @override
  State<ConsoleWidget> createState() => _ConsoleWidgetState();
}

class _ConsoleWidgetState extends State<ConsoleWidget> {
  ScrollController? scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    widget.output.addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    widget.output.removeListener(_scrollToEnd);
    scrollController?.dispose();
    scrollController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appModel = Provider.of<AppModel>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border:
            widget.showDivider
                ? Border(
                  top: Divider.createBorderSide(
                    context,
                    width: 8.0,
                    color: theme.colorScheme.surface,
                  ),
                )
                : null,
      ),
      padding: const EdgeInsets.all(denseSpacing),
      child: ListenableBuilder(
        listenable: widget.output,
        builder: (context, _) {
          return Stack(
            children: [
              SizedBox.expand(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    widget.output.valueToDisplay,
                    maxLines: null,
                    style: GoogleFonts.robotoMono(
                      fontSize: theme.textTheme.bodyMedium?.fontSize,
                      color: switch (widget.output.hasError) {
                        false => theme.textTheme.bodyMedium?.color,
                        true => theme.colorScheme.error.darker,
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(denseSpacing),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (genAiEnabled && appModel.consoleShowingError)
                      MiniIconButton(
                        icon: Image.asset(
                          'assets/gemini_sparkle_192.png',
                          width: 16,
                          height: 16,
                        ),
                        tooltip: 'Suggest fix',
                        onPressed:
                            () => suggestFix(
                              context: context,
                              appType: appModel.appType,
                              errorMessage: widget.output.error,
                            ),
                      ),
                    MiniIconButton(
                      icon: const Icon(Icons.playlist_remove),
                      tooltip: 'Clear console',
                      onPressed:
                          widget.output.isEmpty
                              ? null
                              : () => widget.output.clear(),
                    ),
                  ],
                ),
              ),
              // If there is a JS error, and the app type is Flutter, show a
              // "File an issue" button. JS errors are normal when executing
              // Dart (non-Flutter) code.
              if (widget.output.hasError &&
                  widget.output.hasJavascriptError &&
                  appModel.appIsFlutter.value == true)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Oops! Something went wrong.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      SizedBox(width: 12),
                      FileIssueButton(errorMessage: widget.output.error),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _scrollToEnd() {
    if (!mounted) return;
    final controller = scrollController;
    if (controller == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!controller.hasClients) return;

      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: animationDelay,
        curve: animationCurve,
      );
    });
  }
}

class FileIssueButton extends StatelessWidget {
  final String errorMessage;
  const FileIssueButton({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(switch (theme.brightness) {
          Brightness.light => theme.colorScheme.surface.darker,
          _ => theme.colorScheme.surface.lighter,
        }),
        foregroundColor: WidgetStateProperty.all(theme.colorScheme.onPrimary),
      ),
      child: Text('File an issue'),
      onPressed: () {
        final issueBody = _createGithubIssue(errorMessage);
        const labels = 'type-bug';
        final encodedIssueTitle = Uri.encodeComponent('Console error');
        final encodedIssueBody = Uri.encodeComponent(issueBody);
        final encodedLabels = Uri.encodeComponent(labels);

        final String githubIssueUrl =
            'https://github.com/dart-lang/dart-pad/issues/new?'
            'title=$encodedIssueTitle'
            '&body=$encodedIssueBody'
            '&labels=$encodedLabels';
        launchUrl(Uri.parse(githubIssueUrl));
      },
    );
  }

  String _createGithubIssue(String stackTrace) {
    return '''DartPad displayed an unexpected error in the console:

```
$stackTrace
```
''';
  }
}
