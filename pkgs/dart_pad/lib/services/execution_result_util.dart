// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const testKey = '__TESTRESULT__ ';

const frameTestResultDecoration = '''
void _result(bool success, [List<String> messages = const []]) {
  // Join messages into a comma-separated list for inclusion in the JSON array.
  final joinedMessages = 
      messages.map((m) => '"\${m.replaceAll('"', '\\\\"')}"').join(',');
  print('$testKey{"success": \$success, "messages": [\$joinedMessages]}');
}

// Ensure we have at least one use of `_result`.
var resultFunction = _result;

// Placeholder for unimplemented methods in dart-pad exercises.
// ignore: non_constant_identifier_names
Never TODO([String message = '']) => throw UnimplementedError(message);
''';
