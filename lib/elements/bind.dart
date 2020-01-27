// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.bind;

import 'dart:async';

/// Bind changes from `from` to the target `to`. `from` can be a [Stream] or a
/// [Property]. `to` can be a [Function] or a [Property].
Binding bind(from, to) {
  if (to is! Function && to is! Property) {
    throw ArgumentError('`to` must be a Function or a Property');
  }

  // TODO: handle a Function - use polling (and the browser tick event?)

  if (from is Stream) {
    return _StreamBinding(from, to);
  } else if (from is Property) {
    return _PropertyBinding(from, to);
  } else {
    throw ArgumentError('`from` must be a Stream or a Property');
  }
}

/// A `Property` is able to get its value, change its value, and report changes
/// to its value.
abstract class Property<T> {
  T get();
  void set(T value);
  Stream<T> get onChanged;
}

/// A [Property] backed by a getter and setter pair. Currently it cannot report
/// changes to its value.
class FunctionProperty implements Property {
  final Function getter;
  final Function setter;

  FunctionProperty(this.getter, this.setter);

  @override
  dynamic get() => getter();

  @override
  void set(value) {
    setter(value);
  }

  // TODO:
  @override
  Stream get onChanged => null;
}

/// An object that can own a set of properties.
abstract class PropertyOwner {
  List<String> get propertyNames;
  Property property(String name);
}

/// An instantiation of a binding from one element to another. [Binding]s can be
/// cancelled, so changes are no longer propagated from the source to the
/// target.
abstract class Binding {
  /// Explicitly push the value from the source to the target. This might be a
  /// no-op for some types of bindings.
  void flush();

  /// Cancel the binding; no more changes will be delivered from the source to
  /// the target.
  void cancel();
}

class _StreamBinding implements Binding {
  final Stream stream;
  final dynamic target;

  StreamSubscription _sub;

  _StreamBinding(this.stream, this.target) {
    _sub = stream.listen(_handleEvent);
  }

  @override
  void flush() {}

  @override
  void cancel() {
    _sub.cancel();
  }

  void _handleEvent(e) {
    _sendTo(target, e);
  }
}

class _PropertyBinding implements Binding {
  final Property property;
  final dynamic target;

  StreamSubscription _sub;

  _PropertyBinding(this.property, this.target) {
    var stream = property.onChanged;
    if (stream != null) _sub = stream.listen(_handleEvent);
  }

  @override
  void flush() => _sendTo(target, property.get());

  @override
  void cancel() {
    if (_sub != null) _sub.cancel();
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
