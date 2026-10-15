// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

void main() {
  test('recognizes Markdown extensions case-insensitively', () {
    expect(isMarkdownFile('docs/README.MD'), isTrue);
    expect(isMarkdownFile('docs/readme.markdown'), isTrue);
    expect(isMarkdownFile('docs/readme.md.dart'), isFalse);
  });

  test('renders headings, inline formatting, tables and code', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
# Readme

Some **bold** and *italic* text with `inline code`.

| Name | Value |
| --- | --- |
| Dart | 42 |

```dart
if (a < b && b > 0) {}
```
''');
    final root = renderer.container;
    expect(root.querySelector('h1')?.textContent, 'Readme');
    expect(root.querySelector('strong')?.textContent, 'bold');
    expect(root.querySelector('em')?.textContent, 'italic');
    expect(root.querySelector('td')?.textContent, 'Dart');
    expect(root.querySelector('pre code')?.textContent, 'if (a < b && b > 0) {}\n');
  });

  test('renders allowed HTML and sanitizes scripts, attributes and styles', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
<div onclick="alert(1)" style="position: fixed">Hello</div>

<script>alert(1)</script>

Fish & chips < 3 and &amp; entities.
''');
    final root = renderer.container;
    expect(root.querySelector('div')?.textContent, 'Hello');
    expect(root.querySelector('script, [onclick], [style]'), isNull);
    expect(root.textContent, contains('Fish & chips < 3 and & entities.'));
  });

  test('hides HTML comments and preserves them in code and escaped text', () {
    final renderer = MarkdownRenderer();
    renderer.render(r'''
<!-- Hidden block -->
# Readme

Hello <!-- Hidden inline -->**world**.

`<!-- Inline code -->`

```html
<!-- Fenced code -->
```

\<!-- Escaped comment -->

&lt;!-- Encoded comment --&gt;
''');
    final root = renderer.container;
    expect(root.querySelector('h1')?.textContent, 'Readme');
    expect(root.querySelector('p')?.textContent, 'Hello world.');
    expect(root.textContent, isNot(contains('Hidden')));
    expect(root.querySelector('p code')?.textContent, '<!-- Inline code -->');
    expect(root.querySelector('pre code')?.textContent, '<!-- Fenced code -->\n');
    expect(root.textContent, contains('<!-- Escaped comment -->'));
    expect(root.textContent, contains('<!-- Encoded comment -->'));
  });

  test('sanitizes executable URLs and configures external links and images', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
[unsafe](javascript:alert%281%29)
[data](data:text/html,test)
[tab](java&#x09;script:alert%281%29)
[file](file:///etc/passwd)
[safe](https://dart.dev 'Title" onclick="alert(1)')
[mail](mailto:hello@example.com)
![blocked](javascript:alert%281%29)
![logo](https://dart.dev/logo.png)
''');
    final root = renderer.container;
    expect(root.querySelectorAll('a[href]').length, 2);
    final safe = root.querySelector('a[href="https://dart.dev"]')!;
    expect(safe.getAttribute('title'), 'Title" onclick="alert(1)');
    expect(safe.hasAttribute('onclick'), isFalse);
    expect(safe.getAttribute('target'), '_blank');
    expect(safe.getAttribute('rel'), 'noopener noreferrer nofollow ugc');
    expect(safe.getAttribute('referrerpolicy'), 'no-referrer');
    expect(root.querySelector('img')!.hasAttribute('src'), isFalse);
    expect(root.querySelector('img[src]')!.getAttribute('src'), 'https://dart.dev/logo.png');
    expect(root.querySelector('img[src]')!.getAttribute('referrerpolicy'), 'no-referrer');
  });

  test('preserves encoded HTML and code as literal text', () {
    final renderer = MarkdownRenderer()
      ..render('''
&lt;script&gt;alert(1)&lt;/script&gt;

`<img src="x" onerror="alert(1)">`
''');
    expect(renderer.container.querySelector('script, img'), isNull);
    expect(renderer.container.textContent, contains('<script>alert(1)</script>'));
    expect(renderer.container.querySelector('code')!.textContent, '<img src="x" onerror="alert(1)">');
  });

  test('keeps the DOM for unchanged content and replaces it on edits', () {
    final renderer = MarkdownRenderer()..render('# Original');
    final heading = renderer.container.firstChild!;
    renderer.render('# Original');
    // dart2wasm may wrap the same DOM node in distinct Dart objects.
    expect(renderer.container.firstChild!.isSameNode(heading), isTrue);
    renderer.render('# Updated');
    expect(renderer.container.textContent?.trim(), 'Updated');
    expect(renderer.container.firstChild!.isSameNode(heading), isFalse);
  });

  test('relative resources never fall back to the DartPad web server', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
[Guide](guide.md)

![Logo](assets/logo.png)

[Heading](#heading)

<picture><source srcset="assets/logo.png"><img src="assets/fallback.png"></picture>
''');
    expect(renderer.container.querySelector('a[href], img[src], source[srcset]'), isNull);
    expect(renderer.container.querySelector('img')!.getAttribute('alt'), 'Logo');
  });
}
