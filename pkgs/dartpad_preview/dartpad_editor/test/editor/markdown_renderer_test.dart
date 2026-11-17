// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('recognizes Markdown extensions case-insensitively', () {
    expect(isMarkdownFile('docs/README.MD'), isTrue);
    expect(isMarkdownFile('docs/readme.markdown'), isTrue);
    expect(isMarkdownFile('docs/readme.md.dart'), isFalse);
  });

  test('renders headings, inline formatting, tables and code', () {
    final root = _render('''
# Readme

Some **bold** and *italic* text with `inline code`.

| Name | Value |
| --- | --- |
| Dart | 42 |

```dart
if (a < b && b > 0) {}
```
''');
    expect(root.querySelector('h1')?.textContent, 'Readme');
    expect(root.querySelector('strong')?.textContent, 'bold');
    expect(root.querySelector('em')?.textContent, 'italic');
    expect(root.querySelector('td')?.textContent, 'Dart');
    expect(root.querySelector('pre code')?.textContent, 'if (a < b && b > 0) {}\n');
  });

  test('renders allowed HTML and sanitizes scripts, attributes and styles', () {
    final root = _render('''
<div onclick="alert(1)" style="position: fixed">Hello</div>

<script>alert(1)</script>

Fish & chips < 3 and &amp; entities.
''');
    expect(root.querySelector('div')?.textContent, 'Hello');
    expect(root.querySelector('script, [onclick], [style]'), isNull);
    expect(root.textContent, contains('Fish & chips < 3 and & entities.'));
  });

  test('hides HTML comments and preserves them in code and escaped text', () {
    final root = _render(r'''
<!-- Hidden block -->
<!--
Hidden multiline comment
with **formatting** and <script>alert(1)</script>
-->
# Readme

Hello <!-- Hidden inline -->**world**.

`<!-- Inline code -->`

```html
<!-- Fenced code -->
<!--
Multiline fenced comment
-->
```

\<!-- Escaped comment -->

&lt;!-- Encoded comment --&gt;
''');
    expect(root.querySelector('h1')?.textContent, 'Readme');
    expect(root.querySelector('p')?.textContent, 'Hello world.');
    expect(root.textContent, isNot(contains('Hidden')));
    expect(root.querySelector('p code')?.textContent, '<!-- Inline code -->');
    expect(root.querySelector('pre code')?.textContent, '<!-- Fenced code -->\n<!--\nMultiline fenced comment\n-->\n');
    expect(root.textContent, contains('<!-- Escaped comment -->'));
    expect(root.textContent, contains('<!-- Encoded comment -->'));
  });

  test('sanitizes executable URLs and preserves safe links and images', () {
    final root = _render('''
[unsafe](javascript:alert%281%29)
[data](data:text/html,test)
[tab](java&#x09;script:alert%281%29)
[file](file:///etc/passwd)
[safe](https://dart.dev 'Title" onclick="alert(1)')
[mail](mailto:hello@example.com)
![blocked](javascript:alert%281%29)
![logo](https://dart.dev/logo.png)
''');
    expect(root.querySelectorAll('a[href]').length, 2);
    final safe = root.querySelector('a[href="https://dart.dev"]')!;
    expect(safe.getAttribute('title'), 'Title" onclick="alert(1)');
    expect(safe.hasAttribute('onclick'), isFalse);
    expect(root.querySelector('img')!.hasAttribute('src'), isFalse);
    expect(root.querySelector('img[src]')!.getAttribute('src'), 'https://dart.dev/logo.png');
  });

  test('preserves encoded HTML and code as literal text', () {
    final root = _render('''
&lt;script&gt;alert(1)&lt;/script&gt;

`<img src="x" onerror="alert(1)">`
''');
    expect(root.querySelector('script, img'), isNull);
    expect(root.textContent, contains('<script>alert(1)</script>'));
    expect(root.querySelector('code')!.textContent, '<img src="x" onerror="alert(1)">');
  });

  test('preserves relative links and images for browser resolution', () {
    final root = _render('''
[Guide](guide.md)

![Logo](assets/logo.png)

[Heading](#heading)

<picture><source srcset="assets/logo.png"><img src="assets/fallback.png"></picture>
''');
    expect(root.querySelector('a')!.getAttribute('href'), 'guide.md');
    expect(root.querySelector('img')!.getAttribute('src'), 'assets/logo.png');
    expect(root.querySelector('img')!.getAttribute('alt'), 'Logo');
    expect(root.querySelector('a[href="#heading"]'), isNotNull);
    expect(root.querySelector('source')!.getAttribute('srcset'), 'assets/logo.png');
    expect(root.querySelector('picture img')!.getAttribute('src'), 'assets/fallback.png');
  });
}

web.HTMLDivElement _render(String content) => web.HTMLDivElement()..innerHTML = renderMarkdown(content).toJS;
