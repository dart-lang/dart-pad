// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.util;

import 'dart:async';
import 'dart:html';

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
 * Text to be displayed to DartPad users. The associated title should be
 * 'About DartPad' (or equivalent).
 */
final String privacyText = '''
DartPad is a free, open-source service to help developers learn about the Dart
language and libraries. Source code entered into DartPad may be sent to servers
running in Google Cloud Platform to be analyzed for errors/warnings, compiled to
JavaScript, and returned to the browser.
<br><br>
Source code entered into DartPad may be stored, processed, and aggregated in
order to improve the user experience of DartPad and other Dart tools. For
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

/**
 * Thrown when a cancellation occurs whilst waiting for a result.
 */
class CancellationException implements Exception {
  final String reason;

  CancellationException(this.reason);

  String toString() {
    String result = "Request cancelled";
    if (reason != null) result = "$result due to: $reason";
    return result;
  }
}

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

  void cancel({String reason : "cancelled"}) {
    if (!_cancelled) {
      if (!isCompleted) completeError(new CancellationException(reason));
      _cancelled = true;
    }
  }

  bool get isCancelled => _cancelled;
}

String capitalize(String s) {
  if (s == null) {
    return null;
  } else if (s.length <= 1) {
    return s.toUpperCase();
  } else {
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}
