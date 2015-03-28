// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.bind;

import 'dart:async';

abstract class Property {
  void set(value);
  dynamic get();
  Stream get onChanged;
}

class FunctionProperty implements Property {
  final Function getter;
  final Function setter;

  FunctionProperty(this.getter, this.setter);

  dynamic get() => getter();

  void set(value) {
    setter(value);
  }

  // TODO:
  Stream get onChanged => null;
}

abstract class PropertyOwner {
  List<String> get propertyNames;
  Property property(String name);
}

Binding bind(from, to) {
  if (to is! Function && to is! Property) {
    throw new ArgumentError('`to` must be a Function or a Property');
  }

  // TODO: handle a Function - use polling (and the browser tick event?)

  if (from is Stream) {
    return new _StreamBinding(from, to);
  } else if (from is Property) {
    return new _PropertyBinding(from, to);
  } else {
    throw new ArgumentError('`from` must be a Stream or a Property');
  }
}

abstract class Binding {
  void cancel();
}

class _StreamBinding implements Binding {
  final Stream stream;
  final dynamic target;

  StreamSubscription _sub;

  _StreamBinding(this.stream, this.target) {
    _sub = stream.listen(_handleEvent);
  }

  void cancel() {
    _sub.cancel();
  }

  void _handleEvent(e) => _sendTo(target, e);
}

class _PropertyBinding implements Binding {
  final Property property;
  final dynamic target;

  StreamSubscription _sub;

  _PropertyBinding(this.property, this.target) {
    _sub = property.onChanged.listen(_handleEvent);
  }

  void cancel() {
    _sub.cancel();
  }

  void _handleEvent(e) => _sendTo(target, e);
}

void _sendTo(target, e) {
  if (target is Function) {
    target(e);
  } else if (target is Property) {
    if (e != target.get()) target.set(e);
  }
}
