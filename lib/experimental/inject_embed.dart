// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:dart_pad/util/logging.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:logging/logging.dart';
import 'package:dart_pad/experimental/inject_parser.dart';

Logger _logger = Logger('dartpad-embed');

// Use this prefix for local development:
//var iframePrefix = '';
var iframePrefix = 'https://dartpad.dev/experimental/';

/// Replaces all code snippets marked with the 'run-dartpad' class with an
/// instance of DartPad.
void main() {
  _logger.onRecord.listen(logToJsConsole);
  var snippets = querySelectorAll('code');
  for (var snippet in snippets) {
    if (snippet.classes.isEmpty) {
      continue;
    }

    var className = snippet.classes.first;
    var parser = LanguageStringParser(className);
    if (!parser.isValid) {
      continue;
    }

    _injectEmbed(snippet, parser.options);
  }
}

String iframeSrc(Map<String, String> options) {
  String theme;
  if (options.containsKey('theme')) {
    theme = options['theme'];
  } else {
    theme = 'light';
  }

  String mode;
  if (options.containsKey('mode')) {
    mode = options['mode'];
  } else {
    mode = 'dart';
  }

  return '${iframePrefix}embed-new-$mode.html?theme=$theme';
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
void _injectEmbed(Element snippet, Map<String, String> options) {
  var preElement = snippet.parent;
  if (preElement is! PreElement) {
    _logUnexpectedHtml();
    return;
  }

  if (preElement.children.length != 1) {
    _logUnexpectedHtml();
    return;
  }

  var files = _parseFiles(HtmlUnescape().convert(snippet.innerHtml));

  var hostIndex = preElement.parent.children.indexOf(preElement);
  var host = DivElement();
  preElement.parent.children[hostIndex] = host;

  InjectedEmbed(host, files, options);
}

Map<String, String> _parseFiles(String snippet) {
  return InjectParser(snippet).read();
}

/// Clears children in [host], instantiates an iframe, and sends it a message
/// with the source code when it's ready
class InjectedEmbed {
  final DivElement host;
  final Map<String, String> files;
  final Map<String, String> options;

  InjectedEmbed(this.host, this.files, this.options) {
    _init();
  }

  Future _init() async {
    host.children.clear();

    var iframe = IFrameElement()..setAttribute('src', iframeSrc(options));
    iframe.style.setProperty('border', '1px solid #ccc');

    host.children.add(iframe);

    window.addEventListener('message', (dynamic e) {
      if (e.data['type'] == 'ready') {
        var m = {'sourceCode': files, 'type': 'sourceCode'};
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
