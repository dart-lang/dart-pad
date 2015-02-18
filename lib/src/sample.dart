// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.sample;

final String dartCode = r'''
void main() {
  for (int i = 0; i < 5; i++) {
    print('hello ${i + 1}');
  }
}
''';

final String htmlCode = r'''
<h2>Dart Sample</h2>

<p id="output">Hello world!<p>
''';

final String cssCode = r'''
p {
  color: #888;
}
''';
