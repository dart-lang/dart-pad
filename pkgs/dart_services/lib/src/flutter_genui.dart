// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> invokeFlutterGenUi({
  required String prompt,
  String? apiKey,
}) async {
  final response = await _requestGenui(prompt: prompt, apiKey: apiKey);
  if (response.statusCode == 200) {
    print('Success: ${response.body}');
  } else {
    print('Failed: ${response.statusCode}');
  }
}

Future<http.Response> _requestGenui({required String prompt, String? apiKey}) {
  final keyParem = apiKey == null ? '' : '?key=$apiKey';

  return http.post(
    Uri.parse(
      'https://autopush-devgenui.sandbox.googleapis.com/v1beta1/firstparty/generateidecode$keyParem',
    ),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'userPrompt': 'hello, genui',
      'modelUrl': 'genuigemini://models/gemini-2.0-flash',
    }),
  );
}
