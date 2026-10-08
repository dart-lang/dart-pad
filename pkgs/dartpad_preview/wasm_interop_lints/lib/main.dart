// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/avoid_js_identity.dart';
import 'src/avoid_js_int_cast.dart';
import 'src/fixes.dart';

final plugin = WasmInteropPlugin();

/// Registers portability checks and fixes for JavaScript and Wasm backends.
final class WasmInteropPlugin extends Plugin {
  @override
  String get name => 'Wasm interop lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(AvoidJsIdentity());
    registry.registerFixForRule(AvoidJsIdentity.code, UseJsEquality.new);
    registry.registerLintRule(AvoidJsIntCast());
    registry.registerFixForRule(AvoidJsIntCast.code, ConvertJsNumberToInt.new);
  }
}
