// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';

/// A sandboxed environment for code preview.
abstract interface class PreviewSandbox {
  void dispose();
  Future<void> loadModule({required String code});
  Future<void> runApp(Uri libraryUri);
  Future<void> runMain(Uri libraryUri);
  Future<void> hotReload({required String? code, required List<Uri> librariesToReload});
  Stream<ConsoleMessage> get onConsole;
  Stream<({String message})> get onError;
  Stream<({String message})> get onUnhandledRejection;
}

/// A wrapper around [Sandbox] implementing [PreviewSandbox].
class RealPreviewSandbox implements PreviewSandbox {
  RealPreviewSandbox(this._sandbox);

  final Sandbox _sandbox;

  @override
  void dispose() => _sandbox.dispose();

  @override
  Future<void> loadModule({required String code}) => _sandbox.loadModule(code: code);

  @override
  Future<void> runApp(Uri libraryUri) => _sandbox.runApp(libraryUri);

  @override
  Future<void> runMain(Uri libraryUri) => _sandbox.runMain(libraryUri);

  @override
  Future<void> hotReload({required String? code, required List<Uri> librariesToReload}) =>
      _sandbox.hotReload(code: code, librariesToReload: librariesToReload);

  @override
  Stream<ConsoleMessage> get onConsole => _sandbox.onConsole;

  @override
  Stream<({String message})> get onError => _sandbox.onError;

  @override
  Stream<({String message})> get onUnhandledRejection => _sandbox.onUnhandledRejection;
}
