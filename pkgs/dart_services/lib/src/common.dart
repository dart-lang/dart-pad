// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const kMainDart = 'main.dart';

const kBootstrapDart = 'bootstrap.dart';

const kBootstrapDartCode = r'''
import 'main.dart' as user_code;

void main() {
  user_code.main();
}
''';

// This code should be kept up-to-date with
// https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/web/bootstrap.dart#L236.
const kBootstrapFlutterCode = r'''
import 'dart:ui_web' as ui_web;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'generated_plugin_registrant.dart';
import 'main.dart' as entrypoint;

Future<void> main() async {
  registerPlugins(webPluginRegistrar);
  await ui_web.bootstrapEngine(
    runApp: () {
      return entrypoint.main();
    },
  );
}
''';

const kBootstrapFlutterCode_3_16 = r'''
import 'dart:ui' as ui;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'generated_plugin_registrant.dart';
import 'main.dart' as entrypoint;

Future<void> main() async {
  registerPlugins(webPluginRegistrar);
  await ui.webOnlyInitializePlatform();
  entrypoint.main();
}
''';
