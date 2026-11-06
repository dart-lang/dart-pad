// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

final _mobileUserAgent = RegExp(
  r'Android|iPhone|iPad|iPod|Mobi',
  caseSensitive: false,
);

/// Whether the user agent identifies a mobile device, independent of viewport
/// width and orientation.
bool isMobileBrowser() => _mobileUserAgent.hasMatch(web.window.navigator.userAgent);
