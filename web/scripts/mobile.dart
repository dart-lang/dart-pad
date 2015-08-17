// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../lib/mobile/mobile.dart' as mobile;
import '../../lib/polymer/polymer.dart';

void main() {
  Polymer.whenReady().then((_) {
    mobile.init();
  });
}
