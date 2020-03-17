// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

void main() {
  querySelector('#sendButton').onClick.listen((MouseEvent e) {
    final code = querySelector('#code').text;
    final jsonData = <String, String>{'source': code};
    final api = (querySelector('#apiEndPoint') as InputElement).value;

    final sw = Stopwatch()..start();
    HttpRequest.request(api, method: 'POST', sendData: json.encode(jsonData))
        .then((HttpRequest request) {
      sw.stop();
      querySelector('#perf').text = '${sw.elapsedMilliseconds}ms';
      querySelector('#output').text = request.responseText;
    });
  });
}
