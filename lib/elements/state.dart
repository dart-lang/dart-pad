// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A library for storing non-semantic user state, like UI component positions.
/// This information is differentiated from user configurable settings.
library dart_pad.state;

import 'dart:convert' show json;
import 'dart:html';

abstract class State {
  dynamic operator [](String key);
  void operator []=(String key, dynamic value);
}

class HtmlState implements State {
  final String id;
  Map<String, dynamic> _values = {};

  HtmlState(this.id) {
    if (window.localStorage.containsKey(id)) {
      _values = json.decode(window.localStorage[id]) as Map<String, dynamic>;
    }
  }

  @override
  dynamic operator [](String key) => _values[key];

  @override
  void operator []=(String key, dynamic value) {
    _values[key] = value;
    window.localStorage[id] = json.encode(_values);
  }
}
