// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file has been automatically generated - please do not edit it manually.

class Sample {
  final String name;
  final String id;
  final String? subcategory;
  final String? icon;
  final String archivePath;
  final String entryPath;

  const Sample({
    required this.name,
    required this.id,
    this.subcategory,
    this.icon,
    required this.archivePath,
    required this.entryPath,
  });

  @override
  String toString() => '$name ($id)';
}

abstract final class Samples {
  static const List<Sample> create = [
    _dart,
    _flutter,
  ];

  static const List<Sample> examples = [
    _fibonacci,
    _helloWorld,
    _counter,
    _sunflower,
    _flameGame,
  ];

  static const List<Sample> all = [
    _dart,
    _flutter,
    _fibonacci,
    _helloWorld,
    _counter,
    _sunflower,
    _flameGame,
  ];

  static Sample? getById(String? id) {
    for (final sample in all) {
      if (sample.id == id) {
        return sample;
      }
    }
    return null;
  }

  static const Sample defaultSample = _counter;
}

const _dart = Sample(
  name: 'Dart snippet',
  id: 'dart',
  icon: 'images/dart_logo_192.png',
  archivePath: 'samples/dart.tar.gz',
  entryPath: 'lib/main.dart',
);
const _flutter = Sample(
  name: 'Flutter snippet',
  id: 'flutter',
  icon: 'images/flutter_logo_192.png',
  archivePath: 'samples/flutter.tar.gz',
  entryPath: 'lib/main.dart',
);
const _fibonacci = Sample(
  name: 'Fibonacci',
  id: 'fibonacci',
  subcategory: 'Dart',
  icon: 'images/dart_logo_192.png',
  archivePath: 'samples/fibonacci.tar.gz',
  entryPath: 'lib/main.dart',
);
const _helloWorld = Sample(
  name: 'Hello world',
  id: 'hello-world',
  subcategory: 'Dart',
  icon: 'images/dart_logo_192.png',
  archivePath: 'samples/hello-world.tar.gz',
  entryPath: 'lib/main.dart',
);
const _counter = Sample(
  name: 'Counter',
  id: 'counter',
  subcategory: 'Flutter',
  icon: 'images/flutter_logo_192.png',
  archivePath: 'samples/counter.tar.gz',
  entryPath: 'lib/main.dart',
);
const _sunflower = Sample(
  name: 'Sunflower',
  id: 'sunflower',
  subcategory: 'Flutter',
  icon: 'images/flutter_logo_192.png',
  archivePath: 'samples/sunflower.tar.gz',
  entryPath: 'lib/main.dart',
);
const _flameGame = Sample(
  name: 'Flame game',
  id: 'flame-game',
  subcategory: 'Ecosystem',
  icon: 'images/flame_logo_192.png',
  archivePath: 'samples/flame-game.tar.gz',
  entryPath: 'lib/main.dart',
);