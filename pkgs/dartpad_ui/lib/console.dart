// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'suggest_fix.dart';
import 'theme.dart';
import 'widgets.dart';

class ConsoleWidget extends StatefulWidget {
  final bool showDivider;
  final ValueNotifier<String> output;

  const ConsoleWidget({
    this.showDivider = true,
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

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: widget.showDivider
            ? Border(
                top: Divider.createBorderSide(
                context,
                width: 8.0,
                color: theme.colorScheme.surface,
              ))
            : null,
      ),
      padding: const EdgeInsets.all(denseSpacing),
      child: ValueListenableBuilder(
        valueListenable: widget.output,
        builder: (context, consoleOutput, _) => Stack(
          children: [
            SizedBox.expand(
              child: SingleChildScrollView(
                controller: scrollController,
                child: SelectableText(
                  consoleOutput,
                  maxLines: null,
                  style: GoogleFonts.robotoMono(
                    fontSize: theme.textTheme.bodyMedium?.fontSize,
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
                  MiniIconButton(
                    icon: Image.asset(
                      'gemini_sparkle_192.png',
                      width: 16,
                      height: 16,
                    ),
                    tooltip: 'Suggest fix',
                    onPressed: consoleOutput.isEmpty
                        ? null
                        : () => suggestFix(
                              context: context,
                              errorMessage: consoleOutput,
                            ),
                  ),
                  MiniIconButton(
                    icon: const Icon(Icons.playlist_remove),
                    tooltip: 'Clear console',
                    onPressed: consoleOutput.isEmpty ? null : _clearConsole,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearConsole() {
    widget.output.value = '';
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
