// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _logger = Logger('genui');

class _GenuiEnv {
  late final Uri? apiUrl;
  final String name;

  _GenuiEnv({
    required this.name,
    required String apiKeyVarName,
    required String url,
  }) {
    final key = Platform.environment[apiKeyVarName] ?? '';
    if (key.isEmpty) {
      _logger.warning(
        '$apiKeyVarName not set; genui features at $name DISABLED',
      );
      apiUrl = null;
    } else {
      _logger.info('$apiKeyVarName set; genui features at $name ENABLED');
      apiUrl = Uri.parse('$url?key=$key');
    }
  }

  /// Request code generation from GenUI.
  ///
  /// Returns the generated Flutter code.
  ///
  /// If not enabled or fails, logs error and returns null.
  Future<String?> request({required String prompt}) async {
    final uri = apiUrl;
    if (uri == null) {
      _logger.warning('Genui features at $name are disabled');
      return null;
    }

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'userPrompt': prompt,
        'modelUrl': 'genuigemini://models/gemini-2.0-flash',
      }),
    );

    if (response.statusCode != 200) {
      _logger.warning(
        'Failed to generate ui at genui, $name: ${response.statusCode}, ${response.body}',
      );
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final flutterCode = decoded['flutterCode'] as String;

    return flutterCode;
  }
}

class GenUi {
  late final _GenuiEnv _prodGenui, _stagingGenui;

  GenUi() {
    _prodGenui = _GenuiEnv(
      name: 'prod',
      apiKeyVarName: 'GENUI_API_KEY',
      url:
          'https://devgenui.pa.googleapis.com/v1internal/firstparty/generateidecode',
    );

    _stagingGenui = _GenuiEnv(
      name: 'staging',
      apiKeyVarName: 'GENUI_API_KEY_STAGING',
      url:
          'https://autopush-devgenui.sandbox.googleapis.com/v1beta1/firstparty/generateidecode',
    );
  }

  Future<String> generateCode({required String prompt}) async {
    final prodResult = await _prodGenui.request(prompt: prompt);

    if (prodResult != null) {
      return prodResult;
    }

    final stagingResult = await _stagingGenui.request(prompt: prompt);

    if (stagingResult == null) {
      throw Exception('Failed to generate code from GenUI');
    }

    return stagingResult;
  }
}
