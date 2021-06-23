// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

import 'package:dart_pad/embed.dart';
import 'package:logging/logging.dart';

void main() {
  init(EmbedOptions(EmbedMode.dart));

  Logger.root.onRecord.listen(print);
}
