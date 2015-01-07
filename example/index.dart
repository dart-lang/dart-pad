// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:html";

main() {
  querySelector('#sendButton').onClick.listen((e) {
    String code = querySelector('#code').text;
    var foo = querySelector('#apiEndPoint');
    String api = (querySelector('#apiEndPoint') as InputElement).value;

    Stopwatch sw = new Stopwatch()..start();
    HttpRequest.request(api, method: 'POST',
            sendData: code).then((HttpRequest request) {
      sw.stop();
      querySelector('#perf').text = "${sw.elapsedMilliseconds}ms";
      querySelector('#output').text = request.responseText;
    });
  });
}
