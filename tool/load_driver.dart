// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;

const POST_PAYLOAD =
r'''{"source": "import 'dart:html'; void main() {var count = querySelector('#count');for (int i = 0; i < 4; i++) {count.text = '${i}';print('hello ${i}');}}''';
const EPILOGUE = '"}';

const URI = "https://dart-services.appspot.com/api/dartservices/v1/compile";

int count = 0;

void main(List<String> args) {
  int qps;

  if (args.length == 1) {
    qps = int.parse(args[0]);
  } else {
    qps = 1;
  }

  print("QPS: $qps, URI: $URI");

  int ms = (1000 / qps).floor();
  new Timer.periodic(
      new Duration(milliseconds: ms),
      (t) => pingServer(t));
}

pingServer(Timer t) {
  count++;

  if (count > 1000) {
    t.cancel();
    return;
  }

  Stopwatch sw = new Stopwatch()..start();

  int time = new DateTime.now().millisecondsSinceEpoch;
  
  String message = '$POST_PAYLOAD //$time $EPILOGUE';
  print(message);
  http.post(Uri.parse(URI), body: message).then((response) {
    print("${response.statusCode}, ${sw.elapsedMilliseconds}");
  });
}
