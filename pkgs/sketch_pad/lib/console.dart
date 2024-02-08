// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

class ConsoleWidget extends StatefulWidget {
  final bool showDivider;
  final TextEditingController textController;

  const ConsoleWidget({
    this.showDivider = true,
    required this.textController,
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
    widget.textController.addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_scrollToEnd);
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
                top: Divider.createBorderSide(context,
                    width: 8.0, color: theme.colorScheme.surface))
            : null,
      ),
      padding: const EdgeInsets.all(denseSpacing),
      child: Stack(
        children: [
          TextField(
            controller: widget.textController,
            scrollController: scrollController,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            expands: true,
            decoration: null,
            style:
                theme.textTheme.bodyMedium!.copyWith(fontFamily: 'RobotoMono'),
            readOnly: true,
          ),
          Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder(
                  valueListenable: widget.textController,
                  builder: (context, value, _) {
                    return MiniIconButton(
                      icon: Icons.playlist_remove,
                      tooltip: 'Clear console',
                      onPressed: value.text.isEmpty ? null : _clearConsole,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _clearConsole() {
    widget.textController.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      scrollController?.animateTo(
        scrollController!.position.maxScrollExtent,
        duration: animationDelay,
        curve: animationCurve,
      );
    });
  }
}
