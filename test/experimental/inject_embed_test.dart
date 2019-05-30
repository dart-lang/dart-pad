// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:test/test.dart';
import 'package:dart_pad/experimental/inject_embed.dart' as inject_embed;

void main() {
  group('inject_embed', () {
    setUp(() {
      // todo: determine how to load embed-new.html and other assets
      inject_embed.iframeSrc = 'embed-new.html?fw=true';
      inject_embed.main();
    });
    test('injects a DartPad iframe with a correct code snippet', () async {
      var iframes = querySelectorAll('iframe');
      expect(iframes.length, 1);

      var iframe = iframes.first;
      expect(iframe, TypeMatcher<IFrameElement>());

      // todo: determine how to load embed-new.html and other assets
      // run 'pub run test -p chrome -n "inject_embed" --pause-after-load` to
      // reproduce
      //  expect(iframe.querySelector('#navbar'), isNotNull);
    });
  });
}
