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
  late final String keyHint;

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
      keyHint = '${key[0]}..${key[key.length - 1]}';
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
        'skipPayload': 'true',
      }),
    );

    if (response.statusCode != 200) {
      _logger.warning(
        'Failed to generate ui with genui, $name: '
        '${response.statusCode}; '
        'response-headers: ${response.headers}; '
        'key: $keyHint; '
        '${response.body.replaceAll('\n', ' ')}',
      );
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final flutterCode = decoded['flutterCode'] as String;

    return flutterCode;
  }
}

class GenUi {
  late final _GenuiEnv _primaryGenui, _fallbackGenui;

  GenUi() {
    // TODO(polina-c): make prod primary when b/407075363 is investigated and b/406570040 is fixed
    _fallbackGenui = _GenuiEnv(
      name: 'prod;fallback',
      apiKeyVarName: 'GENUI_API_KEY',
      url:
          'https://devgenui.pa.googleapis.com/v1internal/firstparty/generateidecode',
    );

    _primaryGenui = _GenuiEnv(
      name: 'staging;primary',
      apiKeyVarName: 'GENUI_API_KEY_STAGING',
      url:
          'https://autopush-devgenui.sandbox.googleapis.com/v1beta1/firstparty/generateidecode',
    );
  }

  Future<String> generateCode({required String prompt}) async {
    final prodResult = await _primaryGenui.request(prompt: prompt);

    if (prodResult != null) {
      return prodResult;
    }

    final stagingResult = await _fallbackGenui.request(prompt: prompt);

    if (stagingResult == null) {
      throw Exception('Failed to generate code from GenUI');
    }

    return stagingResult;
  }
}
