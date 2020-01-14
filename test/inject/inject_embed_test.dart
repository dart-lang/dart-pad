// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:test/test.dart';
import 'package:dart_pad/inject/inject_embed.dart' as inject_embed;

// todo (ryjohn): determine how to load embed-flutter.html and other assets.
//
// The test package doesn't build assets in the web/ directory. Run 'pub run
// test -p chrome -n "inject_embed" --pause-after-load` to reproduce
void main() {
  group('inject_embed', () {
    setUp(() {
      inject_embed.iframePrefix = '';
      inject_embed.main();
    });

    test('injects a DartPad iframe with a correct code snippet', () async {
      var iframes = querySelectorAll('iframe');
      var iframe = iframes.first;
      expect(iframe, TypeMatcher<IFrameElement>());
      expect(iframe.attributes['src'],
          'embed-flutter.html?theme=dark&run=false&split=false&ga_id=example1');
    });
  });
}
