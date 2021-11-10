// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Runs [fn] up to three times, catching thrown exceptions, until it returns
/// normally.
Future<void> tryWithReruns(FutureOr<void> Function() fn) async {
  for (var i = 0; i < 3; i++) {
    try {
      await fn();
      // If the function returns normally, continue.
      return;
    } catch (e) {
      print('Setup function threw: $e;');
      if (i < 2) {
        print('Retrying...');
      } else {
        rethrow;
      }
    }
  }
}
