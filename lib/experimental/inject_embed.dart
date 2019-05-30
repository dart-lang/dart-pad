// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:dart_pad/util/logging.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:logging/logging.dart';

Logger _logger = Logger('dartpad-embed');

// Use this location for local development:
// var iframeSrc = 'embed-new.html?fw=true';
var iframeSrc =
    'https://dartpad.dartlang.org/experimental/embed-new.html?fw=true';

/// Replaces all code snippets marked with the 'dartpad-embed' class with an
/// instance of DartPad.
void main() {
  _logger.onRecord.listen(logToJsConsole);
  var hosts = querySelectorAll('.dartpad-embed');
  for (var host in hosts) {
    _injectEmbed(host);
  }
}

/// Replaces [host] with an instance of DartPad as an embedded iframe.
///
/// Code snippets are assumed to be a div containing `pre` and `code` tags:
///
/// <div class="dartpad-embed">
///   <pre>
///     <code>
///       void main() => print("Hello, World!");
///     </code>
///   </pre>
/// </div>
void _injectEmbed(DivElement host) {
  if (host.children.length != 1) {
    _logUnexpectedHtml();
    return;
  }

  var preElement = host.children.first;
  if (preElement.children.length != 1) {
    _logUnexpectedHtml();
    return;
  }

  var codeElement = preElement.children.first;
  var code = HtmlUnescape().convert(codeElement.innerHtml);
  if (code.isEmpty) {
    return;
  }

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
<div class="dartpad-embed">
  <pre>
    <code>
      [code here]
    </code>
  </pre>
</div>''';
  _logger.warning(message);
}
