// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

const BASE_URI = "http://localhost:8080/api/dartservices/v1/";
const count = 5;

main(List<String> args) async {
  String source =
    "import 'dart:html'; void main() { var a = 3; var b = a.abs(); }";

  for (int j = 0; j < count; j++) {
    var data = { "offset": 17,
      "source" : source
    };

    String postPayload = convert.JSON.encode(data);

    await request("complete", postPayload);
    await request("analyze", postPayload);
    await request("compile", postPayload);

  }
}

request(String verb, String postPayload) async {
  return http.post(
      Uri.parse(BASE_URI + verb),
      body: postPayload).then((response) {
    print("${response.statusCode}");
    print("${response.body}");
    return response.statusCode;
  });
}

