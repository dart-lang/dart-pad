// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart' as http;

class FlutterSampleLoader {
  final http.Client client = http.Client();

  Future<String> loadFlutterSample({
    required String sampleId,
    String? channel,
  }) async {
    // There are only two hosted versions of the docs: master/main and stable.
    final sampleUrl = switch (channel) {
      'master' => 'https://main-api.flutter.dev/snippets/$sampleId.dart',
      'main' => 'https://main-api.flutter.dev/snippets/$sampleId.dart',
      _ => 'https://api.flutter.dev/snippets/$sampleId.dart',
    };

    final response = await client.get(Uri.parse(sampleUrl));

    if (response.statusCode != 200) {
      throw Exception('Unable to load sample '
          '(${response.statusCode} ${response.reasonPhrase}})');
    }

    return response.body;
  }

  void dispose() {
    client.close();
  }
}
