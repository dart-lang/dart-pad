// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:html_unescape/html_unescape.dart';
import 'package:logging/logging.dart';

import '../util/logging.dart';
import 'inject_parser.dart';

Logger _logger = Logger('dartpad-embed');

// Use this prefix for local development:
//var iframePrefix = '../';
var iframePrefix = 'https://dartpad.dev/';

/// Replaces all code snippets marked with the 'run-dartpad' class with an
/// instance of DartPad.
void main() {
  _logger.onRecord.listen(logToJsConsole);
  final snippets = querySelectorAll('code');
  for (final snippet in snippets) {
    if (snippet.classes.isEmpty) {
      continue;
    }

    final className = snippet.classes.first;
    final parser = LanguageStringParser(className);
    if (!parser.isValid) {
      continue;
    }

    _injectEmbed(snippet, parser.options);
  }
}

String iframeSrc(Map<String, String> options) {
  final prefix = 'embed-${_valueOr(options, 'mode', 'dart')}.html';
  final theme = 'theme=${_valueOr(options, 'theme', 'light')}';
  final run = 'run=${_valueOr(options, 'run', 'false')}';
  final split = 'split=${_valueOr(options, 'split', 'false')}';
  // A unique ID used to distinguish between DartPad instances in an article or
  // codelab.
  final analytics = 'ga_id=${_valueOr(options, 'ga_id', 'false')}';

  return '$iframePrefix$prefix?$theme&$run&$split&$analytics';
}

String? _valueOr(Map<String, String> map, String value, String defaultValue) {
  if (map.containsKey(value)) {
    return map[value];
  }

  return defaultValue;
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
  final preElement = snippet.parent;
  if (preElement is! PreElement) {
    _logUnexpectedHtml();
    return;
  }

  if (preElement.children.length != 1) {
    _logUnexpectedHtml();
    return;
  }

  final files = _parseFiles(HtmlUnescape().convert(snippet.innerHtml!));

  final hostIndex = preElement.parent!.children.indexOf(preElement);
  final host = DivElement();
  preElement.parent!.children[hostIndex] = host;

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

    final iframe = IFrameElement()..attributes = {'src': iframeSrc(options)};

    if (options.containsKey('width')) {
      iframe.style.width = options['width'];
    }

    if (options.containsKey('height')) {
      iframe.style.height = options['height'];
    }

    host.children.add(iframe);

    window.addEventListener('message', (dynamic e) {
      if (e.data['type'] == 'ready') {
        final m = {'sourceCode': files, 'type': 'sourceCode'};
        iframe.contentWindow!.postMessage(m, '*');
      }
    });
  }
}

void _logUnexpectedHtml() {
  final message = '''Incorrect HTML for "dartpad-embed". Please use this format:
<pre>
  <code class="run-dartpad">
    [code here]
  </code>
</pre>
''';
  _logger.warning(message);
}
