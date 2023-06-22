// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:dart_pad/services/execution_result_util.dart' as util;
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('Execution service result utils', () {
    test('frameTestResultDecoration defined correctly', () {
      expect(
        util.frameTestResultDecoration,
        r'''
void _result(bool success, [List<String> messages = const []]) {
  // Join messages into a comma-separated list for inclusion in the JSON array.
  final joinedMessages = 
      messages.map((m) => '"${m.replaceAll('"', '\\"')}"').join(',');
  print('__TESTRESULT__ {"success": $success, "messages": [$joinedMessages]}');
}

// Ensure we have at least one use of `_result`.
var resultFunction = _result;

// Placeholder for unimplemented methods in dart-pad exercises.
// ignore: non_constant_identifier_names
Never TODO([String message = '']) => throw UnimplementedError(message);
''',
      );
    });

    test('frameTestResultDecoration functions as expected', () async {
      final codeWithResultInserted = Uri.dataFromString(
        '''
import 'dart:async';
import 'dart:isolate';
        
${util.frameTestResultDecoration}      
      
void main(List<String> args, SendPort sendPort) {
  runZonedGuarded(
    () {
      _result(false, ['The Text widget for the name should use the "headlineSmall" textStyle.']);
    },
    (error, stack) {
      sendPort.send(error);
    },
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, string) => sendPort.send(string),
    ),
  );
}
''',
        mimeType: 'application/dart',
      );

      final receivePort = ReceivePort();
      await Isolate.spawnUri(codeWithResultInserted, [], receivePort.sendPort);
      final result = await receivePort.first;
      receivePort.close();

      expect(
        result,
        equals(
          '__TESTRESULT__ {"success": false, "messages": ["The Text widget for the name should use the \\"headlineSmall\\" textStyle."]}',
        ),
      );
    });
  });
}
