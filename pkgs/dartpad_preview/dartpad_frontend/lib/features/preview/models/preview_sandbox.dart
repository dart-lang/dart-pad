// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';
import 'package:web/web.dart' as web;

/// An isolated execution environment used by the preview.
abstract interface class PreviewSandbox {
  /// The run modes supported by this sandbox.
  List<String> get modes;

  /// Compiles and runs [path] using [mode].
  Future<({String log})> run(String path, {required String mode});

  /// Recompiles and restarts the current application.
  Future<({String log})> hotRestart();

  /// Compiles and hot reloads changes into the current application.
  Future<({String log})> hotReload();

  /// Standard console messages emitted by the application.
  Stream<String> get console;

  /// Runtime errors emitted by the application.
  Stream<String> get errors;

  /// Unhandled asynchronous errors emitted by the application.
  Stream<String> get unhandledRejections;

  /// Closes the sandbox and releases all associated resources.
  Future<void> close();
}

final class IframePreviewSandbox implements PreviewSandbox {
  IframePreviewSandbox._(this._sandbox, this._iframe, this._mount);
  final Sandbox _sandbox;
  final SandboxedIframe _iframe;
  final web.HTMLElement _mount;
  Future<void>? _closing;

  static Future<PreviewSandbox> create(
    web.Element container, {
    required Uri assetBaseUrl,
    required Workspace workspace,
  }) async {
    // Own a mount immediately: the SDK can fail after inserting its iframe but
    // before returning a SandboxedIframe handle (for example, on timeout).
    final mount = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%';
    container.appendChild(mount);
    SandboxedIframe? iframe;
    try {
      iframe = await DartPadSdk(assetBaseUrl: assetBaseUrl).createSandboxedIframe(mount);
      return IframePreviewSandbox._(await workspace.connectSandboxedIframe(iframe.port), iframe, mount);
    } catch (_) {
      mount.remove();
      await iframe?.close();
      rethrow;
    }
  }

  @override
  List<String> get modes => _sandbox.modes;
  @override
  Future<({String log})> run(String path, {required String mode}) => _sandbox.run(path, mode: mode);
  @override
  Future<({String log})> hotRestart() => _sandbox.hotRestart();
  @override
  Future<({String log})> hotReload() => _sandbox.hotReload();
  @override
  Stream<String> get console => _sandbox.console;
  @override
  Stream<String> get errors => _sandbox.errors;
  @override
  Stream<String> get unhandledRejections => _sandbox.unhandledRejections;

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    try {
      await _sandbox.close();
    } finally {
      _mount.remove();
      await _iframe.close();
    }
  }
}
