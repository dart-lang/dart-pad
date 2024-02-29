// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

/// Extensions to work around Dart compiler issues that result in calls that
/// sandboxed iframes error on.
///
/// If the compilers are adjusted to handle this case or `package:web` provides
/// a helper for this, switch to that.
///
/// Tracked in https://github.com/dart-lang/sdk/issues/54443.
extension HTMLIFrameElementExtension on HTMLIFrameElement {
  /// Send the specified [message] to this iframe, configured with the specified
  /// [optionsOrTargetOrigin].
  void safelyPostMessage(
    JSAny? message,
    String optionsOrTargetOrigin,
  ) {
    // Uses unsafe calls to prevent the Dart web compilers from
    // inserting type or null checks that access restricted properties.
    (this as JSObject)
        .getProperty<JSObject>('contentWindow'.toJS)
        .callMethod('postMessage'.toJS, message, optionsOrTargetOrigin.toJS);
  }
}
