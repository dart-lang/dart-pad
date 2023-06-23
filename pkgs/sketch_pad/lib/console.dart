// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'theme.dart';

class ConsoleWidget extends StatefulWidget {
  final TextEditingController consoleOutputController;

  const ConsoleWidget({
    required this.consoleOutputController,
    super.key,
  });

  @override
  State<ConsoleWidget> createState() => _ConsoleWidgetState();
}

class _ConsoleWidgetState extends State<ConsoleWidget> {
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();

    scrollController = ScrollController();

    widget.consoleOutputController.addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    widget.consoleOutputController.removeListener(_scrollToEnd);
    scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: widget.consoleOutputController,
      scrollController: scrollController,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      expands: true,
      decoration: null,
      style: theme.textTheme.bodyMedium,
      readOnly: true,
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: animationDelay,
        curve: animationCurve,
      );
    });
  }
}
