// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '_frame.dart';
import 'globals.dart';

bool _viewFactoryInitialized = false;

void initViewFactoryImpl() {
  if (_viewFactoryInitialized) return;

  _viewFactoryInitialized = true;

  ui_web.platformViewRegistry.registerViewFactory(
    executionViewType,
    _iFrameFactory,
  );
}

web.Element _iFrameFactory(int viewId) {
  // 'allow-popups' allows plugins like url_launcher to open popups.
  final frame =
      web.document.createElement('iframe') as web.HTMLIFrameElement
        ..sandbox.add('allow-scripts')
        ..sandbox.add('allow-popups')
        ..sandbox.add('allow-popups-to-escape-sandbox')
        ..allow += 'clipboard-write; '
        ..src = 'frame.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

  executionServiceInstance = ExecutionServiceImpl(frame);

  return frame;
}
