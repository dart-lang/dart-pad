// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:http/http.dart' as http;

const BASE_PATH = '/api/dartservices/v2/';

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
const dartCompileData = {'source': dartSource};
const dartDocData = {'offset': 84, 'source': dartSource};
const flutterData = {'offset': 96, 'source': flutterSource};
const flutterCompileDDCData = {'source': flutterSource};
const flutterDocData = {'offset': 93, 'source': flutterSource};

final dartPayload = convert.json.encode(dartData);
final dartCompilePayload = convert.json.encode(dartCompileData);
final dartDocPayload = convert.json.encode(dartDocData);
final flutterPayload = convert.json.encode(flutterData);
final flutterCompileDDCPayload = convert.json.encode(flutterCompileDDCData);
final flutterDocPayload = convert.json.encode(flutterDocData);

String uri;

Future<void> main(List<String> args) async {
  String appHost;

  if (args.isNotEmpty) {
    appHost = '${args[0]}';
  } else {
    print('''Pass the fully qualified dart-services hostname (no protocol, no
path) as the first argument when invoking this script.

For example:

dart warmup.dart 20200124t152413-dot-dart-services-0.appspot.com
''');

    exit(1);
  }

  // Use an insecure connection for test driving to avoid cert problems
  // with the prefixed app version.
  uri = 'http://$appHost$BASE_PATH';

  print('Target URI\n$uri');

  for (var j = 0; j < count; j++) {
    await request('Dart', 'complete', dartPayload);
    await request('Dart', 'analyze', dartPayload);
    await request('Dart', 'compile', dartCompilePayload);
    await request('Dart', 'document', dartDocPayload);
    await request('Flutter', 'complete', flutterPayload);
    await request('Flutter', 'analyze', flutterPayload);
    await request('Flutter', 'compileDDC', flutterCompileDDCPayload);
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
