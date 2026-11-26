// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../shared/browser_device.dart';

/// Avoids starting the memory-intensive analyzer when the browser identifies
/// a phone.
///
/// This is a device heuristic, independent of viewport width and orientation.
bool analyzerEnabledByDefault() => !isMobileBrowser();
