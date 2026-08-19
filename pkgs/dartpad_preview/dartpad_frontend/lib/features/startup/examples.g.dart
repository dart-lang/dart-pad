// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file has been automatically generated - please do not edit it manually.

import 'example.dart';

abstract final class Examples {
  static const List<Example> snippets = [
    _dart,
    _flutter,
  ];

  static const List<Example> samples = [
    _fibonacci,
    _helloWorld,
    _counter,
    _sunflower,
    _flameGame,
  ];

  static const List<Example> all = [
    _fibonacci,
    _helloWorld,
    _counter,
    _sunflower,
    _flameGame,
    _dart,
    _flutter,
  ];

  static Example? getById(String id) {
    for (final example in all) {
      if (example.id == id) {
        return example;
      }
    }
    return null;
  }

  static const Example defaultExample = _counter;
}

const _fibonacci = Example(
  name: 'Fibonacci',
  id: 'fibonacci',
  subcategory: 'Dart',
  icon: 'images/dart_logo_192.png',
  archivePath: 'examples/fibonacci.tar.gz',
  entryPath: 'lib/main.dart',
);
const _helloWorld = Example(
  name: 'Hello world',
  id: 'hello-world',
  subcategory: 'Dart',
  icon: 'images/dart_logo_192.png',
  archivePath: 'examples/hello-world.tar.gz',
  entryPath: 'lib/main.dart',
);
const _counter = Example(
  name: 'Counter',
  id: 'counter',
  subcategory: 'Flutter',
  icon: 'images/flutter_logo_192.png',
  archivePath: 'examples/counter.tar.gz',
  entryPath: 'lib/main.dart',
);
const _sunflower = Example(
  name: 'Sunflower',
  id: 'sunflower',
  subcategory: 'Flutter',
  icon: 'images/flutter_logo_192.png',
  archivePath: 'examples/sunflower.tar.gz',
  entryPath: 'lib/main.dart',
);
const _flameGame = Example(
  name: 'Flame game',
  id: 'flame-game',
  subcategory: 'Ecosystem',
  icon: 'images/flame_logo_192.png',
  archivePath: 'examples/flame-game.tar.gz',
  entryPath: 'lib/main.dart',
);
const _dart = Example(
  name: 'Dart snippet',
  id: 'dart',
  icon: 'images/dart_logo_192.png',
  archivePath: 'examples/dart.tar.gz',
  entryPath: 'lib/main.dart',
);
const _flutter = Example(
  name: 'Flutter snippet',
  id: 'flutter',
  icon: 'images/flutter_logo_192.png',
  archivePath: 'examples/flutter.tar.gz',
  entryPath: 'lib/main.dart',
);
