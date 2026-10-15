// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

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

  test('resolves relative resources against the document and reloads them after a move', () async {
    final loaded = <Uri>[];
    final opened = <Uri>[];
    final renderer = MarkdownRenderer(
      loadImage: (uri) async {
        loaded.add(uri);
        return 'data:image/png;base64,AA==';
      },
      onOpenFile: (uri) async => opened.add(uri),
    );
    const content = '[Guide](../guide.md)\n\n![Logo](assets/logo.png)';
    renderer.render(content, documentUri: Uri(path: '/docs/README.md'));
    await pumpEventQueue();
    expect(loaded.single.path, '/docs/assets/logo.png');
    expect(renderer.container.querySelector('img')!.getAttribute('src'), 'data:image/png;base64,AA==');
    expect(renderer.container.querySelector('img')!.getAttribute('referrerpolicy'), 'no-referrer');
    final event = web.MouseEvent('click', web.MouseEventInit(cancelable: true));
    renderer.container.querySelector('a')!.dispatchEvent(event);
    expect(event.defaultPrevented, isTrue);
    expect(opened.single.path, '/guide.md');
    renderer.render(content, documentUri: Uri(path: '/other/README.md'));
    await pumpEventQueue();
    expect(loaded.last.path, '/other/assets/logo.png');
  });

  test('resolves sanitized HTML links and images through the same virtual filesystem', () async {
    final loaded = <Uri>[];
    final opened = <Uri>[];
    final renderer = MarkdownRenderer(
      onOpenFile: (uri) async => opened.add(uri),
      loadImage: (uri) async {
        loaded.add(uri);
        return 'data:image/png;base64,AA==';
      },
    );
    renderer.render(
      '<a href="../guide.md" onclick="alert(1)">Guide</a><img src="assets/logo.png" onerror="alert(1)">',
      documentUri: Uri(path: '/docs/README.md'),
    );
    await pumpEventQueue();
    expect(loaded.single.path, '/docs/assets/logo.png');
    expect(renderer.container.querySelector('img')!.getAttribute('src'), 'data:image/png;base64,AA==');
    expect(renderer.container.querySelector('[onclick], [onerror]'), isNull);
    renderer.container.querySelector('a')!.dispatchEvent(web.MouseEvent('click', web.MouseEventInit(cancelable: true)));
    expect(opened.single.path, '/guide.md');
  });

  test('an outdated image load cannot overwrite the current preview', () async {
    final pending = Completer<String?>();
    final renderer = MarkdownRenderer(loadImage: (_) => pending.future);
    renderer.render('![Old](old.png)', documentUri: Uri(path: '/README.md'));
    renderer.render('![New](https://example.com/new.png)', documentUri: Uri(path: '/README.md'));
    pending.complete('data:image/png;base64,AA==');
    await pumpEventQueue();
    expect(renderer.container.querySelector('img')!.getAttribute('src'), 'https://example.com/new.png');
  });

  test('unresolved relative resources never fall back to the host web server', () async {
    final renderer = MarkdownRenderer(loadImage: (_) async => throw StateError('Missing image'));
    renderer.render('[Guide](guide.md)\n\n![Logo](logo.png)', documentUri: Uri(path: '/README.md'));
    await pumpEventQueue();
    expect(renderer.container.querySelector('a')!.hasAttribute('href'), isFalse);
    expect(renderer.container.querySelector('img')!.hasAttribute('src'), isFalse);
    expect(renderer.container.querySelector('img')!.getAttribute('alt'), 'Logo');
  });
  test('sanitizes executable URL schemes and browser-normalized controls before loading resources', () async {
    final loaded = <Uri>[];
    final renderer = MarkdownRenderer(
      loadImage: (uri) async {
        loaded.add(uri);
        return 'data:image/png;base64,AA==';
      },
    );
    renderer.render('''
[script](JaVaScRiPt:alert%281%29)
[tab](java&#x09;script:alert%281%29)
[newline](java&#x0a;script:alert%281%29)
[control](&#x01;javascript:alert%281%29)
[file](file:///etc/passwd)
[blob](blob:https://example.com/id)
![data](data:image/png;base64,AA==)
![mail](mailto:hello@example.com)
![script](javascript:alert%281%29)
''', documentUri: Uri(path: '/README.md'));
    await pumpEventQueue();
    expect(renderer.container.querySelector('a[href], img[src]'), isNull);
    expect(loaded, isEmpty);
  });
}
