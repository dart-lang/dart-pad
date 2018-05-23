// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

String uri;

const BASE_URI = "dart-services.appspot.com/api/dartservices/v1/";
// const BASE_URI = "localhost:8080/api/dartservices/v1/";
const count = 100;

Future main(List<String> args) async {
  String appPrefix;
  if (args.length > 0) {
    appPrefix = "${args[0]}.";
  } else {
    appPrefix = "";
  }

  // Use an insecure connection for test driving to avoid cert problems
  // with the prefixed app version.
  uri = "http://$appPrefix$BASE_URI";

  print("Target URI\n$uri");

  String source =
      "import 'dart:html'; void main() { var a = 3; var b = a.abs(); }";

  for (int j = 0; j < count; j++) {
    var data = {"offset": 17, "source": source};
    var strongData = {"offset": 17, "source": source, "strongMode": true};

    String postPayload = convert.json.encode(data);
    String strongPostPayload = convert.json.encode(strongData);

    await request("complete", postPayload);
    await request("analyze", postPayload);
    await request("compile", postPayload);

    await request("complete", strongPostPayload);
    await request("analyze", strongPostPayload);
    await request("compile", strongPostPayload);
  }
}

Future request(String verb, String postPayload) async {
  Stopwatch sw = new Stopwatch()..start();

  var response = await http.post(Uri.parse(uri + verb),
      body: postPayload,
      headers: {'content-type': 'text/plain; charset=utf-8'});

  int status = response.statusCode;

  if (status != 200) {
    print("$verb \t $status \t ${response.body} ${response.headers}");
  } else {
    print("$verb \t ${sw.elapsedMilliseconds} \t $status");
  }
  return response.statusCode;
}
