// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.util;

import 'dart:html';

/// Return whether we are running on a mobile device.
bool isMobile() {
  const mobileSize = 610;

  final width = document.documentElement!.clientWidth;
  final height = document.documentElement!.clientHeight;

  return width <= mobileSize || height <= mobileSize;
}

/// A [NodeValidator] which allows everything.
class PermissiveNodeValidator implements NodeValidator {
  @override
  bool allowsElement(Element element) => true;

  @override
  bool allowsAttribute(Element element, String attributeName, String value) {
    return true;
  }
}

/// Text to be displayed to DartPad users. The associated title should be
/// 'About DartPad' (or equivalent).
const String privacyText = '''
DartPad is a free, open-source service to help developers learn about the Dart 
language and libraries. Source code entered into DartPad may be sent to servers 
running in Google Cloud Platform to be analyzed for errors/warnings, compiled 
to JavaScript, and returned to the browser.
<br><br>
Learn more about how DartPad stores your data in our
<a href="https://dart.dev/tools/dartpad/privacy">privacy notice</a>.
We look forward to your
<a href="https://github.com/dart-lang/dart-pad/issues" target="feedback">feedback</a>.
<br><br>
Made with &lt;3 by Google.
''';

String? capitalize(String? s) {
  if (s == null) {
    return null;
  } else if (s.length <= 1) {
    return s.toUpperCase();
  } else {
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}
