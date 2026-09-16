// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

/// Observable capability for launching an explicitly supplied entrypoint.
abstract interface class RunAvailability implements Listenable {
  /// Whether an entrypoint can be launched now.
  bool get canRun;
}
