// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// Overrides the browser input used by the analyzer policy for one test.
void setUserAgent(String userAgent) {
  final navigator = web.window.navigator;
  final property = 'userAgent'.toJS;
  final original = _getOwnPropertyDescriptor(navigator, property);
  addTearDown(() {
    if (original == null) {
      navigator.delete(property);
    } else {
      _defineProperty(navigator, property, original);
    }
  });
  _defineProperty(navigator, property, {'configurable': true, 'value': userAgent}.jsify() as JSObject);
}

@JS('Object.defineProperty')
external void _defineProperty(JSObject target, JSString property, JSObject descriptor);

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getOwnPropertyDescriptor(JSObject target, JSString property);
