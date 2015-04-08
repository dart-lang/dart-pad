// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.mutable_gist_test;

import 'package:dart_pad/sharing/gists.dart';
import 'package:dart_pad/sharing/mutable_gist.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('MutableGist', () {
    test('mutation causes dirty', () {
      Gist gist = new Gist(description: 'foo');
      MutableGist mgist = new MutableGist(gist);
      expect(mgist.dirty, false);
      mgist.description = 'bar';
      expect(mgist.dirty, true);
    });

    test('undoing mutation clear dirty', () {
      Gist gist = new Gist(description: 'foo');
      MutableGist mgist = new MutableGist(gist);
      expect(mgist.dirty, false);
      mgist.description = 'bar';
      expect(mgist.dirty, true);
      mgist.description = 'foo';
      expect(mgist.dirty, false);
    });

    test('setBackingGist', () {
      Gist gist = new Gist(description: 'foo');
      MutableGist mgist = new MutableGist(gist);
      expect(mgist.dirty, false);
      mgist.description = 'bar';
      expect(mgist.dirty, true);
      mgist.setBackingGist(gist);
      expect(mgist.dirty, false);
    });

    test('createGist', () {
      Gist gist = new Gist(description: 'foo');
      MutableGist mgist = new MutableGist(gist);
      mgist.description = 'bar';
      Gist newGist = mgist.createGist();
      expect(newGist.description, 'bar');
    });
  });
}
