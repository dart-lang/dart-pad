// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.sharing.gist_storage_test;

import 'package:dart_pad/sharing/gist_storage.dart';
import 'package:dart_pad/sharing/gists.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('GistStorage', () {
    test('store', () {
      GistStorage storage = new GistStorage();
      storage.setStoredGist(createSampleGist());
      expect(storage.hasStoredGist, true);
      expect(storage.getStoredGist(), isNotNull);
      expect(storage.storedId, null);
    });

    test('clear', () {
      GistStorage storage = new GistStorage();
      storage.setStoredGist(createSampleGist());
      expect(storage.hasStoredGist, true);
      storage.clearStoredGist();
      expect(storage.hasStoredGist, false);
    });
  });
}
