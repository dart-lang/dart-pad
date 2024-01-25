// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/helpers.dart' as web_helpers;
import 'package:web/web.dart' as web;

import '../model.dart';
import '../theme.dart';
import 'frame.dart';

const String _viewType = 'dartpad-execution';

bool _viewFactoryInitialized = false;
ExecutionService? executionServiceInstance;

final Key _elementViewKey = UniqueKey();

void _initViewFactory() {
  if (_viewFactoryInitialized) return;

  _viewFactoryInitialized = true;

  ui_web.platformViewRegistry.registerViewFactory(_viewType, _iFrameFactory);
}

web.Element _iFrameFactory(int viewId) {
  // 'allow-popups' allows plugins like url_launcher to open popups.
  final frame = web_helpers.createIFrameElement()
    ..sandbox.add('allow-scripts')
    ..sandbox.add('allow-popups')
    ..src = 'frame.html'
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%';

  executionServiceInstance = ExecutionServiceImpl(frame);

  return frame;
}

class ExecutionWidget extends StatefulWidget {
  final AppServices appServices;

  /// Whether the iframe ignores pointer events, for when gestures need to be
  /// handled by the Flutter app.
  final bool ignorePointer;

  ExecutionWidget({
    required this.appServices,
    this.ignorePointer = false,
    super.key,
  }) {
    _initViewFactory();
  }

  @override
  State<ExecutionWidget> createState() => _ExecutionWidgetState();
}

class _ExecutionWidgetState extends State<ExecutionWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    widget.appServices.executionService?.ignorePointer = widget.ignorePointer;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(denseSpacing),
      child: HtmlElementView(
        key: _elementViewKey,
        viewType: _viewType,
        onPlatformViewCreated: (int id) {
          widget.appServices.registerExecutionService(executionServiceInstance);
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

    // Unregister the execution service.
    widget.appServices.registerExecutionService(null);
  }
}
