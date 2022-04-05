// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mutable_gist;

import 'dart:async';

import '../elements/bind.dart';
import 'gists.dart';

/// An overlay on a gist. Used to edit gists, this overlay knows about its dirty
/// state, and can have dirty state listeners.
class MutableGist implements PropertyOwner {
  Gist _backingGist;
  final _localValues = <String, String?>{};

  final _files = <String, MutableGistFile>{};

  final _dirtyChangedController = StreamController<bool>.broadcast();
  final _changedController = StreamController.broadcast();

  MutableGist(this._backingGist);

  bool get hasId => id?.isNotEmpty ?? false;

  bool get dirty => _localValues.isNotEmpty;

  String? get id => _backingGist.id;

  String? get description => _getProperty('description');

  set description(String? value) => _setProperty('description', value);

  String? get htmlUrl => _getProperty('html_url');

  String? get summary => _getProperty('summary');

  bool? get public => _backingGist.public;

  MutableGistFile getGistFile(String name) =>
      _files[name] ??= MutableGistFile._(this, name);

  List<MutableGistFile> getFiles() {
    return [for (final f in _backingGist.files) getGistFile(f.name)];
  }

  Gist get backingGist => _backingGist;

  void setBackingGist(Gist newGist, {bool wipeState = true}) {
    final wasDirty = dirty;
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
  Property<String?> property(String name) => _MutableGistProperty(this, name);

  /// Returns a deep copy of the current [Gist] this [MutableGist] wraps
  Gist createGist({String? summary}) {
    final gist = Gist(
        description: description,
        id: id,
        public: public,
        htmlUrl: htmlUrl,
        summary: summary,
        files: [
          for (final file in getFiles())
            GistFile(name: file.name, content: file.content)
        ]);
    return gist;
  }

  void reset() {
    final wasDirty = dirty;
    _localValues.clear();
    if (wasDirty != dirty) _dirtyChangedController.add(dirty);
    _changedController.add(null);
  }

  String? _getProperty(String key) {
    if (_localValues.containsKey(key)) return _localValues[key];
    return _backingGist[key] as String?;
  }

  void _setProperty(String key, String? data) {
    final wasDirty = dirty;
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

  String? get content => _parent._getProperty(name);

  set content(String? value) {
    _parent._setProperty(name, value);
  }

  Stream<String?>? get onChanged => _parent.property(name).onChanged;
}

/// An entity that can own a gist.
abstract class GistContainer {
  /// The current gist.
  MutableGist get mutableGist;

  /// Use the given gist, instead of the `route` indicated one, for the next
  /// route request.
  void overrideNextRoute(Gist gist);
}

class _MutableGistProperty implements Property<String?> {
  final MutableGist mutableGist;
  final String name;

  final _changedController = StreamController<String?>.broadcast(sync: true);
  String? _value;

  _MutableGistProperty(this.mutableGist, this.name) {
    _value = get();
    mutableGist.onChanged.listen((_) {
      final newValue = get();
      if (newValue != _value) {
        _value = newValue;
        _changedController.add(_value);
      }
    });
  }

  @override
  void set(String? value) {
    mutableGist._setProperty(name, value);
  }

  @override
  String? get() => mutableGist._getProperty(name);

  @override
  Stream<String?> get onChanged => _changedController.stream;

  @override
  String toString() => name;
}
