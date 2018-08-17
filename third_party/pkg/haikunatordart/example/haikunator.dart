// Copyright (c) 2015, Atrox. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library haikunator.example;

import 'package:haikunator/haikunator.dart';

main() {
  // For more examples please take a view at the tests
  print(Haikunator.haikunate(tokenChars: 'abc', delimiter: '+'));
}
