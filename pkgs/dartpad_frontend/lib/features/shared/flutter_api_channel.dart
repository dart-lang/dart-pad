// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Which Flutter API docs host serves a `sample_id`. Unknown values become [stable].
enum FlutterApiChannel {
  stable,
  main;

  /// `main` and `master` select [main]. Any other value, empty or missing, selects [stable].
  /// Callers pass the last value when `channel` repeats.
  static FlutterApiChannel parse(String? value) {
    final normalized = value?.toLowerCase();
    return normalized == 'main' || normalized == 'master' ? main : stable;
  }
}
