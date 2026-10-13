// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

/// Where the pieces needed by inline DartPads are hosted.
///
/// Read from `data-*` attributes on the `<script>` element loading
/// `inline_dartpad.js`, every URL is resolved relative to that script:
///
/// ```html
/// <script src="inline_dartpad.js"
///         data-sdk="dartpad/dart/"
///         data-worker="shared-worker.js"></script>
/// ```
final class InlineDartPadOptions {
  /// Base URL of the DartPad SDK assets (`worker.js`, `sandbox.js`, ...).
  final Uri sdk;

  /// URL of `shared-worker.js`, as written by
  /// `dart run dartpad setup shared-worker`.
  ///
  /// Browsers require this to be on the same origin as the page.
  final Uri worker;

  InlineDartPadOptions({required this.sdk, required this.worker});

  /// Reads options from the `data-sdk` and `data-worker` attributes on
  /// [script], resolving them relative to its `src`.
  factory InlineDartPadOptions.fromScript(web.HTMLScriptElement script) {
    final base = Uri.parse(script.src);
    Uri resolve(String attribute, String fallback) => base.resolve(script.getAttribute(attribute) ?? fallback);
    return InlineDartPadOptions(
      sdk: resolve('data-sdk', 'dartpad/dart/'),
      worker: resolve('data-worker', 'shared-worker.js'),
    );
  }
}
