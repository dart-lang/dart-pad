// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const kMainDart = 'main.dart';

const kBootstrapDart = 'bootstrap.dart';

const kBootstrapDartCode = r'''
import 'main.dart' as user_code;

import 'package:stack_trace/stack_trace.dart';

void main() {
  Chain.capture(user_code.main, onError: (error, chain) {
    print('DartPad caught unhandled ${error.runtimeType}:');
    print('$error');
    final simplifiedChain = chain
        .toString()
        .split('\n')
        .takeWhile((line) => !line.endsWith(r'main$'))
        .join('\n');
    print('$simplifiedChain\nStack trace truncated and adjusted by DartPad...');
  });
}
''';

// This code should be kept up-to-date with
// https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/web/bootstrap.dart#L236.
const kBootstrapFlutterCode = r'''
import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'generated_plugin_registrant.dart' as pluginRegistrant;
import 'main.dart' as entrypoint;

@JS('window')
external JSObject get _window;

Future<void> main() async {
  // Mock DWDS indicators to allow Flutter to register hot reload 'reassemble'
  // extension.
  _window[r'$dwdsVersion'] = true.toJS;
  _window[r'$emitRegisterEvent'] = ((String _) {}).toJS;
  await ui_web.bootstrapEngine(
    runApp: () {
      entrypoint.main();
    },
    registerPlugins: () {
      pluginRegistrant.registerPlugins();
    },
  );
}
''';
