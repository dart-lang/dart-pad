// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:convert';
import 'dart:html';
import 'package:dart_pad/sharing/gists.dart';

/// A class to store gists in html's localStorage.
class GistStorage {
  static final String _key = 'gist';

  String _storedId;

  GistStorage() {
    var gist = getStoredGist();
    if (gist != null) {
      _storedId = gist.id;
    }
  }

  bool get hasStoredGist => window.localStorage.containsKey(_key);

  /// Return the id of the stored gist. This will return `null` if there is no
  /// gist stored.
  String get storedId =>
      _storedId == null || _storedId.isEmpty ? null : _storedId;

  Gist getStoredGist() {
    var data = window.localStorage[_key];
    return data == null
        ? null
        : Gist.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  void setStoredGist(Gist gist) {
    _storedId = gist.id;
    window.localStorage[_key] = gist.toJson();
  }

  void clearStoredGist() {
    _storedId = null;
    window.localStorage.remove(_key);
  }
}
