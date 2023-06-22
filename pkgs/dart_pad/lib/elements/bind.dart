// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Bind changes from `from` to the target `to`.
Binding bind<T>(Property<T> from, Property<T> to) {
  return _PropertyBinding(from, to);
}

/// A `Property` is able to get its value, change its value, and report changes
/// to its value.
abstract class Property<T> {
  T get();
  void set(T value);
  Stream<T>? get onChanged;
}

/// An object that can own a set of properties.
abstract class PropertyOwner<T> {
  List<String> get propertyNames;
  Property<T> property(String name);
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

class _PropertyBinding<T> implements Binding {
  final Property<T> property;
  final Property<T> target;

  StreamSubscription<T>? _sub;

  _PropertyBinding(this.property, this.target) {
    final stream = property.onChanged;
    if (stream != null) _sub = stream.listen(_handleEvent);
  }

  @override
  void flush() => _sendTo(target, property.get());

  @override
  void cancel() {
    if (_sub != null) _sub!.cancel();
  }

  void _handleEvent(T e) => _sendTo(target, e);
}

void _sendTo<T>(Property<T> target, T e) {
  if (e != target.get()) target.set(e);
}
