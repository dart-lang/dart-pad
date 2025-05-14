// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'context.dart';
import 'logging.dart';

final _logger = DartPadLogger('genui');

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
      _logger.genericWarning(
        '$apiKeyVarName not set; genui features at $name DISABLED',
      );
      apiUrl = null;
    } else {
      _logger.genericInfo(
        '$apiKeyVarName set; genui features at $name ENABLED',
      );
      apiUrl = Uri.parse('$url?key=$key');
      keyHint = '${key[0]}..${key[key.length - 1]}';
    }
  }

  /// Request code generation from GenUI.
  ///
  /// Returns the generated Flutter code.
  ///
  /// If not enabled or fails, logs error and returns null.
  Future<String> request(
    DartPadRequestContext ctx, {
    required String prompt,
  }) async {
    final uri = apiUrl;
    if (uri == null) {
      _logger.severe('Genui features at $name are disabled', ctx);
      return '';
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
      // Logs take just first line, so no new lines.
      _logger.severe(
        'Failed to generate ui with genui, $name: '
                '${response.statusCode}; '
                'response-headers: ${response.headers}; '
                'key: $keyHint; '
                '${response.body}'
            .replaceAll('\n', ' '),
        ctx,
      );
      return '';
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final flutterCode = decoded['flutterCode'] as String;

    return flutterCode;
  }
}

class GenUi {
  late final _GenuiEnv _prod;

  GenUi() {
    _prod = _GenuiEnv(
      name: 'prod',
      apiKeyVarName: 'GENUI_API_KEY',
      url:
          'https://devgenui.pa.googleapis.com/v1internal/firstparty/generateidecode',
    );
  }

  Future<String> generateCode(
    DartPadRequestContext ctx, {
    required String prompt,
  }) async {
    try {
      return await _prod.request(ctx, prompt: prompt);
    } catch (e) {
      _logger.severe('Failed to generate code from GenUI: $e', ctx);
      return '';
    }
  }
}
