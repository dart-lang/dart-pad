// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

/// Avoids starting the memory-intensive analyzer when the browser identifies
/// a phone or tablet.
///
/// This is a device heuristic, independent of viewport width and orientation.
bool analyzerEnabledByDefault() => !RegExp(
  r'Android|iPhone|iPad|iPod|Mobi',
  caseSensitive: false,
).hasMatch(web.window.navigator.userAgent);
