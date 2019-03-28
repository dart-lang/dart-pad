// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:convert";
import "dart:html";

void main() {
  querySelector('#sendButton').onClick.listen((MouseEvent e) {
    String code = querySelector('#code').text;
    Map<String, String> jsonData = <String, String>{'source': code};
    //var foo = querySelector('#apiEndPoint');
    String api = (querySelector('#apiEndPoint') as InputElement).value;

    Stopwatch sw = Stopwatch()..start();
    HttpRequest.request(api, method: 'POST', sendData: json.encode(jsonData))
        .then((HttpRequest request) {
      sw.stop();
      querySelector('#perf').text = "${sw.elapsedMilliseconds}ms";
      querySelector('#output').text = request.responseText;
    });
  });
}
