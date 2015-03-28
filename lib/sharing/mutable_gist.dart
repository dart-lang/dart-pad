// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mutable_gist;

import 'dart:async';

import 'gists.dart';
import '../elements/bind.dart';

// TODO: add tests

// TODO: add docs

/// On overlay on a gist. Used to edit gists, this overlay knows about its dirty
/// state, and can have dirty state listeners.
class MutableGist implements PropertyOwner {
  Gist _backingGist;
  Map _localValues = {};

  StreamController _dirtyChangedController = new StreamController.broadcast();
  StreamController _changedController = new StreamController.broadcast();

  MutableGist(this._backingGist);

  bool get dirty => _localValues.isNotEmpty;

  String get id => _backingGist.id;

  String get description => _getProperty('description');

  set description(String value) => _setProperty('description', value);

  String getFileData(String name) => _getProperty(name);

  void setFileData(String name, String data) => _setProperty(name, data);

  void createFile(String name, String data) => _setProperty(name, data);

  Gist get backingGist => _backingGist;

  void setBackingGist(Gist newGist, {bool wipeState: true}) {
    bool wasDirty = dirty;
    if (wipeState) _localValues.clear();
    _backingGist = newGist;
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
    _changedController.add(null);
  }

  //dynamic operator[](String key) => _localValues[key];

  Stream<bool> get onDirtyChanged => _dirtyChangedController.stream;

  Stream get onChanged => _changedController.stream;

  List<String> get propertyNames {
    Set set = new Set();
    set.add('id');
    set.add('description');
    set.addAll(_backingGist.files.map((f) => f.name));
    set.addAll(_localValues.keys);
    return set.toList();
  }

  Property property(String name) => new _MutableGistProperty(this, name);

  String _getProperty(String key) {
    if (_localValues.containsKey(key)) return _localValues[key];
    return _backingGist[key];
  }

  void _setProperty(String key, String data) {
    bool wasDirty = dirty;
    _localValues[key] = data;
    if (_localValues[key] == _backingGist[key]) _localValues.remove(key);
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
    _changedController.add(null);
  }
}

class _MutableGistProperty implements Property {
  final MutableGist mutableGist;
  final String name;

  StreamController _changedController = new StreamController.broadcast();
  dynamic _value;

  _MutableGistProperty(this.mutableGist, this.name) {
    _value = get();
    mutableGist.onChanged.listen((_) {
      var newValue = get();
      if (newValue != _value) {
        _value = newValue;
        _changedController.add(_value);
      }
    });
  }

  void set(value) {
    mutableGist._setProperty(name, value);
  }

  dynamic get() => mutableGist._getProperty(name);

  Stream get onChanged => _changedController.stream;

  String toString() => name;
}
