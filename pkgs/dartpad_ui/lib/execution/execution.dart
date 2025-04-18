// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../model.dart';
import '../theme.dart';

import 'view_factory/globals.dart';
import 'view_factory/view_factory.dart';

final Key _elementViewKey = UniqueKey();

class ExecutionWidget extends StatefulWidget {
  final AppServices appServices;

  final AppModel appModel;

  ExecutionWidget({
    required this.appServices,
    required this.appModel,
    super.key,
  }) {
    initViewFactory();
  }

  @override
  State<ExecutionWidget> createState() => _ExecutionWidgetState();
}

class _ExecutionWidgetState extends State<ExecutionWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.appModel.splitViewDragState,
      builder: (context, _) {
        // Ignore pointer events while the Splitter is being dragged.
        widget.appServices.executionService?.ignorePointer =
            widget.appModel.splitViewDragState.value == SplitDragState.active;
        return Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.all(denseSpacing),
          child: HtmlElementView(
            key: _elementViewKey,
            viewType: executionViewType,
            onPlatformViewCreated: (int id) {
              widget.appServices.registerExecutionService(
                executionServiceInstance,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();

    // Unregister the execution service.
    widget.appServices.registerExecutionService(null);
  }
}
