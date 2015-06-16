// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.bind_test;

import 'dart:async';

import 'package:dart_pad/elements/bind.dart';
import 'package:test/test.dart';

main() => defineTests();

void defineTests() {
  group('bind', () {
    test('get stream changes', () {
      StreamController fromController = new StreamController.broadcast();
      TestProperty to = new TestProperty();
      bind(fromController.stream, to);
      fromController.add('foo');
      return to.onChanged.first.then((_) {
        expect(to.value, 'foo');
      });
    });

    test('get property changes', () {
      TestProperty from = new TestProperty('foo');
      TestProperty to = new TestProperty();
      bind(from, to).flush();
      return to.onChanged.first.then((_) {
        expect(to.value, from.value);
      });
    });

    test('target functions', () {
      TestProperty from = new TestProperty('foo');
      var val;
      var to = (_val) => val = _val;
      bind(from, to).flush();
      expect(val, from.value);
    });

    test('target properties', () {
      TestProperty from = new TestProperty('foo');
      TestProperty to = new TestProperty();
      bind(from, to).flush();
      return to.onChanged.first.then((_) {
        expect(to.value, from.value);
      });
    });

    test('can cancel', () {
      TestProperty from = new TestProperty();
      TestProperty to = new TestProperty();
      Binding binding = bind(from, to);
      from.set('foo');
      binding.cancel();
      from.set('bar');
      return new Future.delayed(Duration.ZERO, () {
        expect(to.value, 'foo');
      });
    });
  });
}

class TestProperty implements Property {
  StreamController _controller = new StreamController(sync: true);
  var value;
  int changedCount = 0;

  TestProperty([this.value]);

  dynamic get() => value;

  void set(val) {
    value = val;
    changedCount++;
    _controller.add(value);
  }

  Stream get onChanged => _controller.stream;
}
