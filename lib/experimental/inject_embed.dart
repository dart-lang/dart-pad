// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:dart_pad/util/logging.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:logging/logging.dart';

Logger _logger = Logger('dartpad-embed');

// Use this location for local development:
// var iframeSrc = 'embed-new-flutter.html?fw=true';
var iframeSrc =
    'https://dartpad.dartlang.org/experimental/embed-new-flutter.html?fw=true';

/// Replaces all code snippets marked with the 'run-dartpad' class with an
/// instance of DartPad.
void main() {
  _logger.onRecord.listen(logToJsConsole);
  var snippets = querySelectorAll('.run-dartpad');
  for (var snippet in snippets) {
    _injectEmbed(snippet);
  }
}

/// Replaces [host] with an instance of DartPad as an embedded iframe.
///
/// Code snippets are assumed to be a div containing `pre` and `code` tags:
///
/// <pre>
///   <code class="run-dartpad langauge-run-dartpad">
///     void main() => print("Hello, World!");
///   </code>
/// </pre>
void _injectEmbed(Element snippet) {
  var preElement = snippet.parent;
  if (preElement is! PreElement) {
    _logUnexpectedHtml();
    return;
  }

  if (preElement.children.length != 1) {
    _logUnexpectedHtml();
    return;
  }

  var code = HtmlUnescape().convert(snippet.innerHtml);
  if (code.isEmpty) {
    return;
  }

  var hostIndex = preElement.parent.children.indexOf(preElement);
  var host = DivElement();
  preElement.parent.children[hostIndex] = host;

  InjectedEmbed(host, code);
}

/// Clears children in [host], instantiates an iframe, and sends it a message
/// with the source code when it's ready
class InjectedEmbed {
  final DivElement host;
  final String code;

  InjectedEmbed(this.host, this.code) {
    _init();
  }

  Future _init() async {
    host.children.clear();

    var iframe = IFrameElement()..setAttribute('src', iframeSrc);
    iframe.style.setProperty('border', '1px solid #ccc');

    host.children.add(iframe);

    window.addEventListener('message', (dynamic e) {
      if (e.data['type'] == 'ready') {
        var m = {'sourceCode': code, 'type': 'sourceCode'};
        iframe.contentWindow.postMessage(m, '*');
      }
    });
  }
}

void _logUnexpectedHtml() {
  var message = '''Incorrect HTML for "dartpad-embed". Please use this format:
<pre>
  <code class="run-dartpad">
    [code here]
  </code>
</pre>
''';
  _logger.warning(message);
}
