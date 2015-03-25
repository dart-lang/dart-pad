// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mutable_gist;

import 'dart:async';

import 'gists.dart';

// TODO: add tests

// TODO: add docs

class MutableGist {
  Gist _backingGist;
  Map _localValues = {};

  StreamController _dirtyChangedController = new StreamController.broadcast();

  MutableGist(this._backingGist);

  bool get dirty => _localValues.isNotEmpty;

  String get id => _backingGist.id;

  String get description => _getProperty('description');

  set description(String value) => _setProperty('description', value);

  String getFileData(String name) => _getProperty(name);

  void setFileData(String name, String data) => _setProperty(name, data);

  void createFile(String name, String data) => _setProperty(name, data);

  set backingGist(Gist newGist) {
    bool wasDirty = dirty;
    _backingGist = newGist;
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
  }

  //dynamic operator[](String key) => _localValues[key];

  Stream<bool> get onDirtyChanged => _dirtyChangedController.stream;

  String _getProperty(String key) {
    if (_localValues.containsKey(key)) return _localValues[key];
    return _backingGist[key];
  }

  void _setProperty(String key, String data) {
    bool wasDirty = dirty;
    _localValues[key] = data;
    if (_localValues[key] == _backingGist[key]) _localValues.remove(key);
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
  }
}
