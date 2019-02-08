// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_pad/new_embed.dart' as new_embed;
import 'package:logging/logging.dart';

void main() {
  print('main() in web script');

  Logger.root.onRecord.listen(print);

  new_embed.init();
}
