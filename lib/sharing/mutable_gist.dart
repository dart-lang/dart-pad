// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mutable_gist;

import 'dart:async';

import '../elements/bind.dart';
import 'gists.dart';

/// On overlay on a gist. Used to edit gists, this overlay knows about its dirty
/// state, and can have dirty state listeners.
class MutableGist implements PropertyOwner {
  Gist _backingGist;
  final _localValues = <String, String>{};

  final _files = <String, MutableGistFile>{};

  final _dirtyChangedController = StreamController<bool>.broadcast();
  final _changedController = StreamController.broadcast();

  MutableGist(this._backingGist);

  bool get hasId => id != null && id.isNotEmpty;

  bool get dirty => _localValues.isNotEmpty;

  String get id => _backingGist.id;

  String get description => _getProperty('description');

  set description(String value) => _setProperty('description', value);

  String get htmlUrl => _getProperty('html_url');

  String get summary => _getProperty('summary');

  bool get public => _backingGist.public;

  MutableGistFile getGistFile(String name) {
    if (_files[name] == null) {
      _files[name] = MutableGistFile._(this, name);
    }
    return _files[name];
  }

  List<MutableGistFile> getFiles() {
    for (final f in _backingGist.files) {
      getGistFile(f.name);
    }
    return _files.values.toList();
  }

  Gist get backingGist => _backingGist;

  void setBackingGist(Gist newGist, {bool wipeState = true}) {
    var wasDirty = dirty;
    if (wipeState) _localValues.clear();
    _backingGist = newGist;
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
    _changedController.add(null);
  }

  Stream<bool> get onDirtyChanged => _dirtyChangedController.stream;

  Stream get onChanged => _changedController.stream;

  @override
  List<String> get propertyNames {
    final set = <String>{};
    set.add('id');
    set.add('description');
    set.add('html_url');
    set.add('summary');
    set.addAll(_backingGist.files.map((f) => f.name));
    set.addAll(_localValues.keys);
    return set.toList();
  }

  @override
  Property<String> property(String name) => _MutableGistProperty(this, name);

  Gist createGist({String summary}) {
    var gist = Gist(description: description, id: id, public: public);
    gist.htmlUrl = htmlUrl;
    for (var file in getFiles()) {
      gist.files.add(GistFile(name: file.name, content: file.content));
    }
    if (summary != null) gist.summary = summary;
    return gist;
  }

  void reset() {
    var wasDirty = dirty;
    _localValues.clear();
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
    _changedController.add(null);
  }

  String _getProperty(String key) {
    if (_localValues.containsKey(key)) return _localValues[key];
    return _backingGist[key] as String;
  }

  void _setProperty(String key, String data) {
    var wasDirty = dirty;
    _localValues[key] = data;
    if (_localValues[key] == _backingGist[key]) _localValues.remove(key);
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
    _changedController.add(null);
  }

  @override
  String toString() => _backingGist.toString();
}

class MutableGistFile {
  final MutableGist _parent;
  final String name;

  MutableGistFile._(this._parent, this.name);

  String get content => _parent._getProperty(name);

  set content(String value) {
    _parent._setProperty(name, value);
  }

  Stream<String> get onChanged => _parent.property(name).onChanged;
}

/// An entity that can own a gist.
abstract class GistContainer {
  /// The current gist.
  MutableGist get mutableGist;

  /// Use the given gist, instead of the `route` indicated one, for the next
  /// route request.
  void overrideNextRoute(Gist gist);
}

class _MutableGistProperty implements Property<String> {
  final MutableGist mutableGist;
  final String name;

  final _changedController = StreamController<String>.broadcast(sync: true);
  String _value;

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

  @override
  void set(value) {
    mutableGist._setProperty(name, value);
  }

  @override
  String get() => mutableGist._getProperty(name);

  @override
  Stream<String> get onChanged => _changedController.stream;

  @override
  String toString() => name;
}
