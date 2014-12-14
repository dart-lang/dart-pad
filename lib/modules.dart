
library modules;

import 'dart:async';

export 'dart:async' show Future;

abstract class Module {

  /**
   * TODO:
   */
  Future init();
}

/**
 * Maintains a list of active modules.
 */
class ModuleManager {
  List<Module> modules = [];
  List<Module> _inited = [];

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
    if (_started) return new Future.value();

    _started = true;

    return Future.forEach(modules, _startModule);
  }

  Future _startModule(Module module) {
    return module.init().catchError((e) {
      // TODO: log
      print(e);
    }).whenComplete(() {
      _inited.add(module);
    });
  }
}
