// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Copied from https://github.com/dart-lang/pub/blob/a9ed06f7fb180b39b950aec878d4aa0911b7675e/lib/src/gzip/gzip_js.dart

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web implementation of gzipDecoder using the browser's `DecompressionStream`.
Converter<List<int>, List<int>> get gzipDecoder => const BrowserGZipDecoder();

/// A [Converter] that decompresses gzip-compressed data using the browser's
/// `DecompressionStream` API.
class BrowserGZipDecoder extends Converter<List<int>, List<int>> {
  const BrowserGZipDecoder();

  @override
  List<int> convert(List<int> input) {
    // The browser's DecompressionStream API is asynchronous, so we cannot
    // implement this synchronously.
    throw UnsupportedError(
      'Synchronous gzip decoding is not supported on the web.',
    );
  }

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) {
    final controller = StreamController<List<int>>();
    unawaited(_pipe(stream, controller));
    return controller.stream;
  }

  bool _isHarmlessPaddingError(Object e) {
    // Some .tar.gz may contain harmless padding, which DecrompressionStream in
    // the browsers are sensitive to. Example:
    // https://pub.dev/api/archives/lints-1.0.1.tar.gz
    final errorMessage = e.toString().toLowerCase();
    // Match the specific EOF padding errors from V8, SpiderMonkey, and WebKit
    return errorMessage.contains('junk found') ||
        errorMessage.contains('unexpected input') ||
        errorMessage.contains('extra bytes');
  }

  Future<void> _pipe(
    Stream<List<int>> stream,
    StreamController<List<int>> controller,
  ) async {
    final decompressionStream = web.DecompressionStream('gzip');
    final writer = decompressionStream.writable.getWriter();
    final reader = decompressionStream.readable.getReader() as web.ReadableStreamDefaultReader;

    final readFuture = () async {
      try {
        while (true) {
          final result = await reader.read().toDart;
          if (result.done) {
            break;
          }
          final value = result.value as JSUint8Array;
          controller.add(value.toDart);
        }
      } catch (e, st) {
        if (_isHarmlessPaddingError(e)) {
          // Ignore trailing junk
          return;
        }
        controller.addError(e, st);
      } finally {
        reader.releaseLock();
      }
    }();

    try {
      await for (final chunk in stream) {
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        await writer.write(bytes.toJS).toDart;
      }
      await writer.close().toDart;
    } catch (e, st) {
      if (_isHarmlessPaddingError(e)) {
        // Ignore trailing junk
      } else {
        controller.addError(e, st);
      }
    } finally {
      await readFuture;
      await controller.close();
    }
  }
}
