// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
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

  test('renders headings, inline formatting, tables, tasks and code', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
# Readme

Some **bold** and *italic* text with `inline code`.

| Name | Value |
| --- | --- |
| Dart | 42 |

- [x] Done
- [ ] Pending

```dart
if (a < b && b > 0) {}
```
''');
    final root = renderer.container;
    expect(root.querySelector('h1')?.textContent, 'Readme');
    expect(root.querySelector('strong')?.textContent, 'bold');
    expect(root.querySelector('em')?.textContent, 'italic');
    expect(root.querySelector('td')?.textContent, 'Dart');
    expect(root.querySelectorAll('input[disabled]').length, 2);
    expect(root.querySelectorAll('input[checked]').length, 1);
    expect(root.querySelector('pre code')?.textContent, 'if (a < b && b > 0) {}\n');
  });

  test('preserves text and escapes raw HTML instead of activating it', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
<script>alert('test')</script>

<img src="x" onerror="alert('test')">

Fish & chips < 3 and &amp; entities.
''');
    expect(renderer.container.querySelector('script, img'), isNull);
    expect(renderer.container.textContent, contains('<script>'));
    expect(renderer.container.textContent, contains('Fish & chips < 3 and & entities.'));
  });

  test('blocks executable URLs while keeping regular links and images', () {
    final renderer = MarkdownRenderer();
    renderer.render('''
[unsafe](javascript:alert%281%29)
[data](data:text/html,test)
[safe](https://dart.dev "Dart")
[mail](mailto:hello@example.com)
![blocked](javascript:alert%281%29)
![logo](https://dart.dev/logo.png)
''');
    final links = renderer.container.querySelectorAll('a');
    expect((links.item(0) as web.Element).hasAttribute('href'), isFalse);
    expect((links.item(1) as web.Element).hasAttribute('href'), isFalse);
    final safe = links.item(2) as web.Element;
    expect(safe.getAttribute('href'), 'https://dart.dev');
    expect(safe.getAttribute('rel'), 'noopener noreferrer');
    expect(safe.getAttribute('title'), 'Dart');
    expect((links.item(3) as web.Element).getAttribute('href'), 'mailto:hello@example.com');
    expect(renderer.container.querySelector('img')!.hasAttribute('src'), isFalse);
    expect(renderer.container.querySelector('img[src]')!.getAttribute('src'), 'https://dart.dev/logo.png');
  });

  test('keeps the DOM for unchanged content and replaces it on edits', () {
    final renderer = MarkdownRenderer()..render('# Original');
    final heading = renderer.container.firstChild;
    renderer.render('# Original');
    expect(renderer.container.firstChild, same(heading));
    renderer.render('# Updated');
    expect(renderer.container.textContent, 'Updated');
    expect(renderer.container.firstChild, isNot(same(heading)));
  });

  test('anchor links scroll only their own preview and duplicate headings have distinct IDs', () {
    final first = MarkdownRenderer();
    final second = MarkdownRenderer();
    final content = '# Section\n\n[Jump](#section-1)\n\n${List.filled(20, 'Paragraph.').join('\n\n')}\n\n# Section';
    first.render(content);
    second.render(content);
    final host = web.HTMLDivElement();
    for (final renderer in [first, second]) {
      renderer.container.style.cssText = 'height: 80px; overflow: auto;';
      host.appendChild(renderer.container);
    }
    web.document.body!.appendChild(host);
    try {
      final headings = host.querySelectorAll('h1');
      final ids = [for (var i = 0; i < headings.length; i++) (headings.item(i) as web.Element).id];
      expect(ids.toSet(), hasLength(4));
      final link = second.container.querySelector('a')! as web.HTMLAnchorElement;
      expect(link.getAttribute('href'), '#${ids.last}');
      final hash = web.window.location.hash;
      link.click();
      expect(second.container.scrollTop, greaterThan(0));
      expect(first.container.scrollTop, 0);
      expect(web.window.location.hash, hash);
    } finally {
      host.remove();
    }
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
    final event = web.MouseEvent('click', web.MouseEventInit(cancelable: true));
    renderer.container.querySelector('a')!.dispatchEvent(event);
    expect(event.defaultPrevented, isTrue);
    expect(opened.single.path, '/guide.md');
    renderer.render(content, documentUri: Uri(path: '/other/README.md'));
    await pumpEventQueue();
    expect(loaded.last.path, '/other/assets/logo.png');
  });

  test('percent-encoded anchors point to the scoped heading', () {
    final renderer = MarkdownRenderer()..render('# Section\n\n[Jump](#%73ection)');
    final heading = renderer.container.querySelector('h1')!;
    final link = renderer.container.querySelector('a')!;
    expect(Uri.decodeComponent(link.getAttribute('href')!.substring(1)), heading.id);
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
}
