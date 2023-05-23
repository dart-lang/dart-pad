// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dart_pad/elements/bind.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('bind', () {
    test('get property changes', () {
      final from = TestProperty('foo');
      final to = TestProperty();
      bind(from, to).flush();
      return to.onChanged.first.then((_) {
        expect(to.value, from.value);
      });
    });

    test('target properties', () {
      final from = TestProperty('foo');
      final to = TestProperty();
      bind(from, to).flush();
      return to.onChanged.first.then((_) {
        expect(to.value, from.value);
      });
    });

    test('can cancel', () {
      final from = TestProperty();
      final to = TestProperty();
      final binding = bind(from, to);
      from.set('foo');
      binding.cancel();
      from.set('bar');
      return Future.delayed(Duration.zero, () {
        expect(to.value, 'foo');
      });
    });
  });
}

class TestProperty implements Property<Object?> {
  final _controller = StreamController<Object?>(sync: true);
  Object? value;
  int changedCount = 0;

  TestProperty([this.value]);

  @override
  Object? get() => value;

  @override
  void set(Object? val) {
    value = val;
    changedCount++;
    _controller.add(value);
  }

  @override
  Stream<Object?> get onChanged => _controller.stream;
}
