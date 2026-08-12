// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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
  Stream<({String kind, Map<String, Object?> data})> get onExtensionEvent;
  Future<String> invokeExtension(String method, Map<String, String> args);
}

/// A wrapper around [Sandbox] implementing [PreviewSandbox] with dynamic event buffering.
class RealPreviewSandbox implements PreviewSandbox {
  RealPreviewSandbox(this._sandbox) {
    _subscription = _sandbox.onExtensionEvent.listen((e) {
      _bufferedEvents.add(e);
      if (!_extensionEventController.isClosed) {
        _extensionEventController.add(e);
      }
    });
  }

  final Sandbox _sandbox;
  late final StreamSubscription<dynamic> _subscription;
  final _bufferedEvents = <({String kind, Map<String, Object?> data})>[];
  final _extensionEventController = StreamController<({String kind, Map<String, Object?> data})>.broadcast();

  @override
  void dispose() {
    _subscription.cancel();
    _extensionEventController.close();
    _sandbox.dispose();
  }

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

  @override
  Stream<({String kind, Map<String, Object?> data})> get onExtensionEvent {
    final controller = StreamController<({String kind, Map<String, Object?> data})>();

    // Immediately yield all buffered events to the new listener
    for (final e in _bufferedEvents) {
      controller.add(e);
    }

    // Listen to new events
    final sub = _extensionEventController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  @override
  Future<String> invokeExtension(String method, Map<String, String> args) => _sandbox.invokeExtension(method, args);
}
