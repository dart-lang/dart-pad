// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library core.modules;

// TODO: test

import 'dart:async';

export 'dart:async' show Future;

abstract class Module {
  /// TODO:
  Future init();
}

/// Maintains a list of active modules.
class ModuleManager {
  List<Module> modules = [];
  final _inited = <Module>[];

  bool _started = false;

  ModuleManager();

  void register(Module module) {
    modules.add(module);

    if (started) {
      _startModule(module);
    }
  }

  bool get started => _started;

  Future start() {
    if (_started) return Future.value();

    _started = true;

    return Future.forEach(modules, _startModule);
  }

  Future _startModule(Module module) {
    // TODO: log errors
    return module.init().catchError(print).whenComplete(() {
      _inited.add(module);
    });
  }
}
