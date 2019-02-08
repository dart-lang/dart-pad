// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library newembed;

import 'package:logging/logging.dart';

NewEmbed get playground => _playground;

NewEmbed _playground;

final _logger = Logger('dartpad');

void init() {
  _playground = NewEmbed();
}

class NewEmbed {
  NewEmbed() {
    print('Created a NewEmbed.');
  }
}
