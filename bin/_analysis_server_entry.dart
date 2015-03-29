// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This starts a copy of the analysis server. It's not a part of the
/// exported application for this package; it's in the `bin/` folder in order
/// to take advantage of the `packages/` symlinks.
library _analysis_server_entry;

import 'package:analysis_server/starter.dart';

/**
 * Create and run an analysis server.
 */
void main(List<String> args) {
  ServerStarter starter = new ServerStarter();
  starter.start(args);
}
