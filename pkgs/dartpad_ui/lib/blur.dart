// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';

import 'package:web/web.dart';

const _flutterViewSelector = 'flutter-view';

void addBlurListener() {
  window.addEventListener('blur', _onBlur.toJS);
}

void removeBlurListener() {
  window.removeEventListener('blur', _onBlur.toJS);
}

void _onBlur(Event _) {
  print('onBlur');
  final activeElement = document.activeElement as HTMLElement?;
  if (activeElement == null) return;
  // Only call blur on elements that are within a Flutter view.
  final inFlutterView = activeElement.closest(_flutterViewSelector) != null;
  print('inFlutterView = $inFlutterView');
  if (inFlutterView) {
    print('activeElement = $activeElement');
    activeElement.blur();
  }
}