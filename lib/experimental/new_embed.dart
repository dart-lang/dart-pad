// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

NewEmbed get playground => _playground;

NewEmbed _playground;
void init() {
  _playground = NewEmbed();
}

class NewEmbed {
  NewEmbed() {
    print('Created a NewEmbed.');
  }
}
