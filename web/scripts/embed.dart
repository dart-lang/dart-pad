// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Currently not in use

import '../../lib/embed/embed.dart' as embed;
import '../../lib/polymer/polymer.dart';

void main() {
  Polymer.whenReady().then((_) {
    embed.init();
  });
}
