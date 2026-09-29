// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Implements the legacy host page's ready/sourceCode handshake.
final class EmbedMessageController {
  EmbedMessageController({required this.onSourceCode}) {
    _subscription = web.EventStreamProviders.messageEvent.forTarget(web.window).listen(_onMessage);
  }

  final Future<void> Function(String sourceCode) onSourceCode;
  late final StreamSubscription<web.MessageEvent> _subscription;
  bool _ready = false;
  bool _disposed = false;
  bool _applying = false;
  String? _pendingSource;

  /// Announces readiness only after the editor can accept code. The listener
  /// is already installed, so even a host that sends early cannot lose its code.
  void ready() {
    if (_disposed || _ready) {
      return;
    }
    _ready = true;
    web.window.parentCrossOrigin?.postMessage(
      {'sender': web.window.name, 'type': 'ready'}.jsify(),
      '*'.toJS,
    );
    unawaited(_applyPending());
  }

  void _onMessage(web.MessageEvent event) {
    // Accept any parent origin (including cross-origin documentation sites),
    // but never treat messages from the execution sandbox as editor commands.
    if (_disposed || event.source.strictNotEquals(web.window.parent).toDart) {
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSObject>()) {
      return;
    }
    final object = data as JSObject;
    final type = object.getProperty<JSAny?>('type'.toJS);
    final source = object.getProperty<JSAny?>('sourceCode'.toJS);
    if (type == null || !type.isA<JSString>() || (type as JSString).toDart != 'sourceCode') {
      return;
    }
    if (source == null || !source.isA<JSString>()) {
      return;
    }
    final code = (source as JSString).toDart;
    if (code.isEmpty) {
      return;
    }
    _pendingSource = code;
    unawaited(_applyPending());
  }

  Future<void> _applyPending() async {
    if (!_ready || _disposed || _applying) {
      return;
    }
    _applying = true;
    try {
      while (!_disposed && _pendingSource != null) {
        final source = _pendingSource!;
        _pendingSource = null;
        await onSourceCode(source);
      }
    } finally {
      _applying = false;
    }
  }

  void dispose() {
    _disposed = true;
    _pendingSource = null;
    unawaited(_subscription.cancel());
  }
}
