// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _logger = Logger('genui');

class GenUi {
  static const _apiKeyVarName = 'GENUI_API_KEY';
  late final String _genuiApiKey;

  GenUi() {
    _genuiApiKey = Platform.environment[_apiKeyVarName] ?? '';
    if (_genuiApiKey.isEmpty) {
      _logger.warning('$_apiKeyVarName not set; genui features DISABLED');
    } else {
      _logger.info('$_apiKeyVarName set; genui features ENABLED');
    }
  }

  Future<String> generateCode({required String prompt}) async {
    final response = await _requestGenUI(prompt: prompt);

    if (response.statusCode != 200) {
      throw Exception('Failed to generate ui: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final flutterCode = decoded['flutterCode'] as String;

    return flutterCode;
  }

  Future<http.Response> _requestGenUI({required String prompt}) async {
    if (_genuiApiKey.isEmpty) {
      throw Exception('Missing environment variable: $_apiKeyVarName');
    }

    return http.post(
      Uri.parse(
        'https://devgenui.pa.googleapis.com/v1internal/firstparty/generateidecode?key=$_genuiApiKey',
      ),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'userPrompt': prompt,
        'modelUrl': 'genuigemini://models/gemini-2.0-flash',
      }),
    );
  }
}
