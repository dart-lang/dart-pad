// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library dart_pad.mutable_gist_test;

import 'package:dart_pad/sharing/gists.dart';
import 'package:dart_pad/sharing/mutable_gist.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('MutableGist', () {
    test('mutation causes dirty', () {
      var gist = Gist(description: 'foo');
      var mgist = MutableGist(gist);
      expect(mgist.dirty, false);
      mgist.description = 'bar';
      expect(mgist.dirty, true);
    });

    test('undoing mutation clear dirty', () {
      var gist = Gist(description: 'foo');
      var mgist = MutableGist(gist);
      expect(mgist.dirty, false);
      mgist.description = 'bar';
      expect(mgist.dirty, true);
      mgist.description = 'foo';
      expect(mgist.dirty, false);
    });

    test('setBackingGist', () {
      var gist = Gist(description: 'foo');
      var mgist = MutableGist(gist);
      expect(mgist.dirty, false);
      mgist.description = 'bar';
      expect(mgist.dirty, true);
      mgist.setBackingGist(gist);
      expect(mgist.dirty, false);
    });

    test('createGist', () {
      var gist = Gist(description: 'foo');
      var mgist = MutableGist(gist);
      mgist.description = 'bar';
      var newGist = mgist.createGist();
      expect(newGist.description, 'bar');
    });
  });
}
