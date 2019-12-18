// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

const BASE_URI = 'dart-services.appspot.com/api/dartservices/v1/';

const count = 200;

const dartSource =
    "import 'dart:html'; void main() { var a = 3; var b = a.abs(); int c = 7;}";

const flutterSource = """import 'package:flutter/material.dart';

void main() {
  final widget = Container(color: Colors.white);
  runApp(widget);
}
""";

const dartData = {'offset': 17, 'source': dartSource};
const dartDocData = {'offset': 84, 'source': dartSource};
const flutterData = {'offset': 96, 'source': flutterSource};
const flutterDocData = {'offset': 93, 'source': flutterSource};

final dartPayload = convert.json.encode(dartData);
final dartDocPayload = convert.json.encode(dartDocData);
final flutterPayload = convert.json.encode(flutterData);
final flutterDocPayload = convert.json.encode(flutterDocData);

String uri;

Future<void> main(List<String> args) async {
  String appPrefix;

  if (args.isNotEmpty) {
    appPrefix = '${args[0]}.';
  } else {
    appPrefix = '';
  }

  // Use an insecure connection for test driving to avoid cert problems
  // with the prefixed app version.
  uri = 'http://$appPrefix$BASE_URI';

  print('Target URI\n$uri');

  for (int j = 0; j < count; j++) {
    await request('Dart', 'complete', dartPayload);
    await request('Dart', 'analyze', dartPayload);
    await request('Dart', 'compile', dartPayload);
    await request('Dart', 'document', dartDocPayload);
    await request('Flutter', 'complete', flutterPayload);
    await request('Flutter', 'analyze', flutterPayload);
    await request('Flutter', 'compileDDC', flutterPayload);
    await request('Flutter', 'document', flutterDocPayload);
  }
}

Future<int> request(String codeType, String verb, String postPayload) async {
  final sw = Stopwatch()..start();

  final response = await http.post(
    Uri.parse(uri + verb),
    body: postPayload,
    headers: {'content-type': 'text/plain; charset=utf-8'},
  );

  final status = response.statusCode;

  if (status != 200) {
    print('$codeType $verb \t $status \t ${response.body} ${response.headers}');
  } else {
    print('$codeType $verb \t ${sw.elapsedMilliseconds} \t $status');
  }

  return response.statusCode;
}
