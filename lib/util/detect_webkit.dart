import 'dart:html';

import 'package:dart_pad/elements/dialog.dart';

const String _message = '''
<p>
It looks like you're using a WebKit-based browser (such as Safari). There's
currently an issue with the way DartPad and WebKit's JavaScript parser interact
that could cause up to a thirty second delay the first time you execute Flutter
code in DartPad. This is not an issue with Dart or Flutter itself, and we're
working with the WebKit team to resolve it.
</p>
<p>
In the meantime, it's possible to avoid the delay by using one of the other
major browsers, such as Firefox, Edge (dev channel), or Chrome.
</p>
''';

/// Returns true if Safari is being used to display the page.
bool isRunningInWebKit() =>
    window.navigator.vendor.contains('Apple') &&
    !window.navigator.userAgent.contains('CriOS') &&
    !window.navigator.userAgent.contains('FxiOS');

/// Shows a custom dialog when Safari is being used to display the page.
///
/// Returns true if Safari is being used.
void notifyIfWebKit(Dialog dialog) {
  // See https://bugs.webkit.org/show_bug.cgi?id=199866.
  if (isRunningInWebKit()) {
    dialog.showOk('Possible delay', _message);
  }
}
