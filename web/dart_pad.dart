// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_pad/playground.dart' as playground;
import 'package:logging/logging.dart';

// TODO: display errors that aren't currently on the screen

// TODO: ensure css works cross-platform: flexbox layout, box-shadow, transitions

// TODO: create a hidden ping time counter - display it on a key combination

void main() {
  Logger.root.onRecord.listen(print);

  playground.init();
}
