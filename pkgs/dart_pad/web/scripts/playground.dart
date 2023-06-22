// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_pad/playground.dart';
import 'package:logging/logging.dart';

void main() async {
  Logger.root.onRecord.listen(print);

  await Playground.initialize();
}
