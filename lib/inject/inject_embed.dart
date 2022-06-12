// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:html_unescape/html_unescape.dart';
import 'package:logging/logging.dart';

import '../util/logging.dart';
import 'inject_parser.dart';

final Logger _logger = Logger('dartpad-embed');

// Use this prefix for local development:
//var iframePrefix = '../';
var iframePrefix = 'https://dartpad.dev/';

final HtmlUnescape _htmlUnescape = HtmlUnescape();

/// Replaces all code snippets marked with the 'run-dartpad' class with an
/// instance of DartPad.
void main() {
  _logger.onRecord.listen(logToJsConsole);
  final snippets = querySelectorAll('code').iterator;
  while (snippets.moveNext()) {
    final snippet = snippets.current;
    if (snippet.classes.isEmpty) {
      continue;
    }

    final className = snippet.classes.first;
    final parser = LanguageStringParser(className);
    final parserOptions = parser.options;

    // If this is the start of a multi-snippet embed ('start-dartpad')
    // loop through remaining snippets
    // until the last one is found ('end-dartpad').
    if (parser.isValid && parser.isStart) {
      final rangeSnippets = [snippet];
      final rangeOptions = [parserOptions];
      var endFound = false;
      while (snippets.moveNext()) {
        final rangedSnippet = snippets.current;
        final rangedParser = LanguageStringParser(rangedSnippet.classes.first);
        rangeSnippets.add(rangedSnippet);
        rangeOptions.add(rangedParser.options);
        if (rangedParser.isEnd) {
          endFound = true;
          break;
        }
      }

      if (!endFound) {
        throw DartPadInjectException(
            "Cannot find closing snippet with 'end-dartpad' class.");
      }

      _injectRangedEmbed(snippet, parserOptions, rangeSnippets, rangeOptions);
    } else {
      if (!parser.isValid) {
        continue;
      }

      _injectEmbed(snippet, parserOptions);
    }
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

/// Replaces [snippet] with an instance of DartPad as an embedded iframe.
///
/// Code snippets are assumed to be a div containing `pre` and `code` tags:
///
/// <pre>
///   <code class="run-dartpad language-run-dartpad">
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

  final files = _parseFiles(_htmlUnescape.convert(snippet.innerHtml!));

  final hostIndex = preElement.parent!.children.indexOf(preElement);
  final host = DivElement();
  preElement.parent!.children[hostIndex] = host;

  InjectedEmbed(host, files, options);
}

Map<String, String> _parseFiles(String snippet) {
  return InjectParser(snippet).read();
}

/// Replaces [firstSnippet] with an instance of DartPad as an embedded iframe
/// using the files from the following snippets.
void _injectRangedEmbed(Element firstSnippet, Map<String, String> firstOptions,
    List<Element> snippets, List<Map<String, String>> options) {
  if (snippets.length != options.length) {
    _logUnexpectedHtml();
    return;
  }

  final preElement = firstSnippet.parent;
  if (preElement is! PreElement) {
    _logUnexpectedHtml();
    return;
  }

  final Map<String, String> files = {};

  for (int i = 0; i < snippets.length; i++) {
    final snippet = snippets[i];
    final snippetName = options[i]['file'];
    if (snippetName == null) {
      throw DartPadInjectException(
          "A ranged dartpad-embed ranged snippet is missing a 'file-' option.");
    }

    final preElement = snippet.parent;
    if (preElement is! PreElement) {
      _logUnexpectedHtml();
      return;
    }

    if (preElement.children.length != 1) {
      _logUnexpectedHtml();
      return;
    }

    files[snippetName] = _htmlUnescape.convert(snippet.innerHtml!);

    if (i != 0) {
      snippet.parent!.remove();
    }
  }

  final firstSiblings = preElement.parent!.children;
  final hostIndex = firstSiblings.indexOf(preElement);

  final host = DivElement();
  firstSiblings[hostIndex] = host;

  InjectedEmbed(host, files, firstOptions);
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
