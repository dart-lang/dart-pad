// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A Dart library to access the Lirato hosted statistics service
 * (https://metrics.librato.com).
 */
library librato;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/**
 * Used for testing.
 */
void main(List<String> args) {
  if (args.length == 3) {
    Librato librato = new Librato(args[0], args[1]);
    librato.postStats('dartpad', {'startupTime': num.parse(args[2])});
  } else {
    print('usage: librato <username> <token> <stat-to-measure>');
  }
}

/**
 * A class used to send statistical data to the Lirato service
 * (https://metrics.librato.com).
 *
 * To use this class, instantiate an instance (with an optional url), and call
 * [postStats] to post a group of statistics.
 */
class Librato {
  static const String DEFAULT_URL = "https://metrics-api.librato.com/v1/metrics";

  final String url;
  final String _username;
  final String _password;

  Librato(this._username, this._password, [this.url = DEFAULT_URL]);

  /**
   * Send a group of statistics. The `groupName` paremeter cooresponds to the
   * Lirato `source`. The keys of the `stats` map should be the names of the
   * statistic, and the cooresponding value in the map should be the numeric
   * value of the statistic.
   */
  Future postStats(String groupName, Map<String, num> stats) {
    var statsList = stats.keys.map((key) {
      return {
          'source': groupName,
          'name': key,
          'value': stats[key]
      };
    }).toList();

    //  { "gauges": [ {...}, {...} ] }
    Map m = { 'gauges': statsList };
    String data = JSON.encode(m);

    HttpClient client = new HttpClient();
    return client.postUrl(Uri.parse(url)).then((HttpClientRequest request) {
      final auth = CryptoUtils.bytesToBase64(
          UTF8.encode("${_username}:${_password}"));
      request.headers.set('authorization', "Basic ${auth}");
      request.headers.contentType = ContentType.JSON;
      request.write(data);
      return request.close();
    }).then((HttpClientResponse response) {
      return response.drain();
    });
  }
}
