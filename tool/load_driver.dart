// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;

const POST_PAYLOAD =
    r'''{"source": "import 'dart:html'; void main() {var count = querySelector('#count');for (int i = 0; i < 4; i++) {count.text = '${i}';print('hello ${i}');}}''';
const EPILOGUE = '"}';

const URI = 'https://dart-services.appspot.com/api/dartservices/v1/compile';

int count = 0;

void main(List<String> args) {
  num qps;

  if (args.length == 1) {
    qps = num.parse(args[0]);
  } else {
    qps = 1;
  }

  print('QPS: $qps, URI: $URI');

  final ms = (1000 / qps).floor();
  Timer.periodic(Duration(milliseconds: ms), pingServer);
}

void pingServer(Timer t) {
  count++;

  if (count > 1000) {
    t.cancel();
    return;
  }

  final sw = Stopwatch()..start();

  final time = DateTime.now().millisecondsSinceEpoch;
  final message = '$POST_PAYLOAD //$time $EPILOGUE';
  print(message);
  http.post(Uri.parse(URI), body: message).then((response) {
    print('${response.statusCode}, ${sw.elapsedMilliseconds}');
  });
}
