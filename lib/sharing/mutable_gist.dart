// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mutable_gist;

import 'dart:async';

import 'gists.dart';
import '../elements/bind.dart';

// TODO: Simplify these classes.

/// On overlay on a gist. Used to edit gists, this overlay knows about its dirty
/// state, and can have dirty state listeners.
class MutableGist implements PropertyOwner {
  Gist _backingGist;
  Map _localValues = {};

  Map<String, MutableGistFile> _files = {};

  StreamController _dirtyChangedController = new StreamController.broadcast();
  StreamController _changedController = new StreamController.broadcast();

  MutableGist(this._backingGist);

  bool get dirty => _localValues.isNotEmpty;

  String get id => _backingGist.id;

  String get description => _getProperty('description');

  set description(String value) => _setProperty('description', value);

  String get html_url => _getProperty('html_url');

  bool get public => _backingGist.public;

//  String getFileData(String name) => _getProperty(name);
//
//  void setFileData(String name, String data) => _setProperty(name, data);

  MutableGistFile getGistFile(String name) {
    if (_files[name] == null) {
      _files[name] = new MutableGistFile._(this, name);
    }
    return _files[name];
  }

  List<MutableGistFile> getFiles() {
    _backingGist.files.forEach((f) => getGistFile(f.name));
    return _files.values.toList();
  }

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
    set.add('html_url');
    set.addAll(_backingGist.files.map((f) => f.name));
    set.addAll(_localValues.keys);
    return set.toList();
  }

  Property property(String name) => new _MutableGistProperty(this, name);

  Gist createGist() {
    Gist gist = new Gist(description: description, id: id, public: public);
    gist.html_url = html_url;
    for (MutableGistFile file in getFiles()) {
      gist.files.add(new GistFile(name: file.name, content: file.content));
    }
    return gist;
  }

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

class MutableGistFile {
  final MutableGist _parent;
  final String name;

  MutableGistFile._(this._parent, this.name);

  String get content => _parent._getProperty(name);

  set content(String value) {
    _parent._setProperty(name, value);
  }

  Stream get onChanged => _parent.property(name).onChanged;
}

/// An entity that can own a gist.
abstract class GistContainer {
  /// The current gist.
  MutableGist get mutableGist;

  /// Use the given gist, instead of the `route` indicated one, for the next
  /// route request.
  void overrideNextRoute(Gist gist);
}

class _MutableGistProperty implements Property {
  final MutableGist mutableGist;
  final String name;

  StreamController _changedController = new StreamController.broadcast(sync: true);
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
