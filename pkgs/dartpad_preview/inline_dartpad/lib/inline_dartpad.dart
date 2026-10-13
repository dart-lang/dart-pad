// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Lightweight DartPads for documentation pages.
///
/// Include the compiled script once per page and mark code blocks:
///
/// ```html
/// <script src="inline_dartpad.js" defer></script>
///
/// <pre data-dartpad-filename="hello.dart" data-dartpad-preview="start"><code>
/// void main() => print('Hello, world!');
/// </code></pre>
/// ```
///
/// See `InlineDartPadOptions` for how to point the script at the DartPad SDK,
/// and `PadSpec` for the `data-dartpad-*` attributes.
library;

export 'src/options.dart';
export 'src/pad.dart' show PadPreview, PadSpec;
export 'src/page.dart';
