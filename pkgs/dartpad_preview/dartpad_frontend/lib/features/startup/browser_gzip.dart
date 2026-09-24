// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Decodes archive bytes with the browser's native streaming gzip decoder.
Stream<List<int>> decodeBrowserGzip(Uint8List bytes) async* {
  final decoder = web.DecompressionStream('gzip');
  final stream = web.Blob([bytes.toJS].toJS).stream().pipeThrough(
    web.ReadableWritablePair(readable: decoder.readable, writable: decoder.writable),
  );
  final reader = stream.getReader() as web.ReadableStreamDefaultReader;
  try {
    while (true) {
      final result = await reader.read().toDart;
      if (result.done) {
        break;
      }
      yield (result.value as JSUint8Array).toDart;
    }
  } catch (error) {
    // Match Pub's handling of gzip EOF padding across browser engines:
    // https://github.com/dart-lang/pub/blob/main/lib/src/gzip/gzip_js.dart
    final message = error.toString().toLowerCase();
    if (!message.contains('junk found') && !message.contains('unexpected input') && !message.contains('extra bytes')) {
      rethrow;
    }
  } finally {
    try {
      await reader.cancel().toDart;
    } catch (_) {
      // An errored stream also rejects cancellation; preserve the read error.
    }
    reader.releaseLock();
  }
}
