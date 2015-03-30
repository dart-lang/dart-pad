// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library options;

import 'dart:async';
import 'dart:js';
import 'dart:html';

/// This options class provides a way to configure dartpad through the JS
/// console. This is useful for things like developer options.
///
/// When in the JS console, you have two functions available to you:
/// listOptions() and setOption(key, value). `listOptions` will print out
/// all the available options, and `setOption` will let you change the value of
/// an option.
class Options {
  final String namespace;

  Map<String, String> _values = {};
  StreamController _controller = new StreamController.broadcast();

  Options({this.namespace: 'dartpad'});

  void installIntoJsContext() {
    Map options = {};

    options['setOption'] = (name, value) {
      setValue('${name}', '${value}');
    };

    options['listOptions'] = () {
      for (String key in keys) {
        window.console.log('[dartpad] ${key}: ${_values[key]}');
      }
    };

    context[namespace] = new JsObject.jsify(options);
  }

  void registerOption(String name, String defaultValue) {
    // Load saved value.
    String savedValue = window.localStorage['${namespace}.${name}'];
    setValue(name, savedValue == null ? defaultValue : savedValue);
  }

  Iterable<String> get keys => _values.keys;

  String getValue(String name) => _values[name];

  /// Return the value for the given name. Coerce to a `bool`, or return `false`
  /// if that is not possible.
  dynamic getValueBool(String name) {
    String val = getValue(name);
    return val == 'true' ? true : false;
  }

  void setValue(String name, String value) {
    if (_values.containsKey(name) && _values[name] == value) return;

    _values[name] = value;
    _controller.add(new OptionChangedEvent(name, value));

    // Persistent the value across sessions.
    window.localStorage['${namespace}.${name}'] = value;
  }

  Stream<OptionChangedEvent> get onOptionChanged => _controller.stream;
}

class OptionChangedEvent {
  final String name;
  final String value;

  OptionChangedEvent(this.name, this.value);

  String toString() => '${name}: ${value}';
}
