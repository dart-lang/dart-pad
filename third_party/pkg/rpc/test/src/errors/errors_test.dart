// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library errors_tests;

import 'package:rpc/rpc.dart';
import 'package:test/test.dart';

main() {
  group('errors-rpc-error-detail-to-json', () {
    test('maps-properly', () async {
      var errorDetail = new RpcErrorDetail();
      expect(errorDetail.toJson(), {});

      var jsonTemplate = {
        'domain': '1',
        'reason': '2',
        'message': '3',
        'location': '4',
        'locationType': '5',
        'extendedHelp': '6',
        'sendReport': '7',
      };
      errorDetail = new RpcErrorDetail(
          domain: jsonTemplate['domain'],
          reason: jsonTemplate['reason'],
          message: jsonTemplate['message'],
          location: jsonTemplate['location'],
          locationType: jsonTemplate['locationType'],
          extendedHelp: jsonTemplate['extendedHelp'],
          sendReport: jsonTemplate['sendReport']);

      expect(errorDetail.toJson(), jsonTemplate);
    });
  });
}
