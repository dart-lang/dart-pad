// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:convert';
import 'dart:html';
import 'gists.dart';

/// A class to store gists in html's localStorage.
class GistStorage {
  static const String _key = 'gist';

  String? _storedId;

  GistStorage() {
    final gist = getStoredGist();
    if (gist != null) {
      _storedId = gist.id;
    }
  }

  bool get hasStoredGist => window.localStorage.containsKey(_key);

  /// Return the id of the stored gist. This will return `null` if there is no
  /// gist stored.
  String? get storedId => _storedId?.isEmpty ?? true ? null : _storedId;

  Gist? getStoredGist() {
    final data = window.localStorage[_key];
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
