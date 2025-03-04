import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> invokeFlutterGenUi() async {
  print('Invoking flutter_gen_ui');

  final response = await _requestGenui();
  if (response.statusCode == 201) {
    print('Success: ${response.body}');
  } else {
    print('Failed: ${response.statusCode}');
  }
}

Future<http.Response> _requestGenui() {
  return http.post(
    Uri.parse(
      'https://autopush-devgenui.sandbox.googleapis.com/v1beta1/firstparty/generateidecode\?key\=AIzaSyA5oU44eMuipFel1jxoYEh',
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
