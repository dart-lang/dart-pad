// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.util;

import 'dart:async';
import 'dart:html';

/**
 * Return whether we are running on a mobile device.
 */
bool isMobile() {
  final int mobileSize = 610;

  int width = document.documentElement.clientWidth;
  int height = document.documentElement.clientHeight;

  return width <= mobileSize || height <= mobileSize;
}

/**
 * A [NodeValidator] which allows everything.
 */
class PermissiveNodeValidator implements NodeValidator {
  bool allowsElement(Element element) => true;
  bool allowsAttribute(Element element, String attributeName, String value) {
    return true;
  }
}

/**
 * Text to be displayed to Dart Pad users. The associated title should be
 * 'About Dart Pad' (or equivalent).
 */
final String privacyText = '''
Dart Pad is a free, open-source service to help developers learn about the Dart
language and libraries. Source code entered into Dart Pad may be sent to servers
running in Google Cloud Platform to be analyzed for errors/warnings, compiled to
JavaScript, and returned to the browser.
<br><br>
Source code entered into Dart Pad may be stored, processed, and aggregated in
order to improve the user experience of Dart Pad and other Dart tools. For
example, we may use the source code to help offer better code completion
suggestions. The raw source code is deleted after 6 months.
<br><br>
Learn more about Google's
<a href="http://www.google.com/policies/privacy/" target="policy">privacy policy</a>.
We look forward to your
<a href="https://github.com/dart-lang/dart-pad/issues" target="feedback">feedback</a>.
<br><br>
Made with &lt;3 by Google.
''';

class CancellableCompleter<T> implements Completer {
  Completer _completer = new Completer();
  bool _cancelled = false;

  CancellableCompleter();

  void complete([value]) {
    if (!_cancelled) _completer.complete(value);
  }

  void completeError(Object error, [StackTrace stackTrace]) {
    if (!_cancelled) _completer.completeError(error, stackTrace);
  }

  Future<T> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    if (!_cancelled) {
      if (!isCompleted) completeError(new TimeoutException('cancelled'));
      _cancelled = true;
    }
  }

  bool get isCancelled => _cancelled;
}
