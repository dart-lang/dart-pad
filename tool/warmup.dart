// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

String uri;

const BASE_URI = "dart-services.appspot.com/api/dartservices/v1/";
// const BASE_URI = "dart-services-test.appspot.com/api/dartservices/v1/";
// const BASE_URI = "localhost:8080/api/dartservices/v1/";
const count = 100;

main(List<String> args) async {

  String appPrefix;
  if (args.length > 0) {
    appPrefix = "${args[0]}.";
  } else {
    appPrefix = "";
  }

  // Use an insecure connection for test driving to avoid cert problems
  // with the prefixed app version.
  uri = "http://$appPrefix$BASE_URI";

  print ("Target URI\n$uri");

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
      Uri.parse(uri + verb),
      body: postPayload,
       headers: {'content-type': 'text/plain; charset=utf-8'}
    ).then((response) {
    print("${response.statusCode}");
    print("${response.body}");
    return response.statusCode;
  });
}
