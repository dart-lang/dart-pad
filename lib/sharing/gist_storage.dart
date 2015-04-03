// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gist_storage;

import 'dart:html';
import 'dart:convert' show JSON;

import 'gists.dart';

/// A class to store gists in html's localStorage.
class GistStorage {
  static final String _key = 'gist';

  String _storedId;

  GistStorage() {
    Gist gist = getStoredGist();
    if (gist != null) {
      _storedId = gist.id;
    }
  }

  bool get hasStoredGist => window.localStorage.containsKey(_key);

  /// Return the id of the stored gist. This will return `null` if there is no
  /// gist stored.
  String get storedId => _storedId;

  Gist getStoredGist() {
    String data = window.localStorage[_key];
    return data == null ? null : new Gist.fromMap(JSON.decode(data));
  }

  void setStoredGist(Gist gist) {
    _storedId = gist.id;
    window.localStorage[_key] = gist.toJson();
  }

  void clearStoredGist() {
    window.localStorage.remove(_key);
  }
}
