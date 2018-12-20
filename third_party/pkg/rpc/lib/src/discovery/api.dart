// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library discovery.api;

import 'config.dart';

import 'package:rpc/rpc.dart';

const _API_NAME = 'discovery';
const _API_VERSION = 'v1';

@ApiClass(name: _API_NAME, version: _API_VERSION)
class DiscoveryApi {
  @ApiResource(name: 'apis')
  final DiscoveryResource apis;

  factory DiscoveryApi(ApiServer server, String apiPrefix) {
    if (apiPrefix == null) {
      apiPrefix = '';
    }
    if (apiPrefix.isNotEmpty && !apiPrefix.startsWith('/')) {
      apiPrefix = '/$apiPrefix';
    }
    if (apiPrefix.endsWith('/')) {
      apiPrefix = apiPrefix.substring(0, apiPrefix.length - 1);
    }
    var apis = new DiscoveryResource(server, apiPrefix);
    return new DiscoveryApi._(apis);
  }

  DiscoveryApi._(this.apis);
}

class DiscoveryResource {
  final ApiServer _server;
  final String _apiPrefix;

  DiscoveryResource(this._server, this._apiPrefix);

  @ApiMethod(
      path: 'apis/{api}/{version}/rest',
      description:
          'Retrieve the description of a particular version of an api.')
  RestDescription getRest(String api, String version) {
    return _server.getDiscoveryDocument(context.baseUrl, '/$api/$version');
  }

  // TODO: support the query string parameters
  @ApiMethod(
      path: 'apis', //?name={name}&preferred={value}
      description: 'Retrieve the list of APIs supported at this endpoint.')
  DirectoryList list() {
    assert(_apiPrefix.isEmpty || _apiPrefix.startsWith('/'));
    assert(!_apiPrefix.endsWith('/'));
    var apiDirectory = _server.getDiscoveryDirectory();
    apiDirectory.forEach((item) {
      // Update each item with the discovery url and path.
      var path = '$_apiPrefix/$_API_NAME/$_API_VERSION/apis/${item.name}/'
          '${item.version}/rest';
      item
        ..discoveryRestUrl = '${context.baseUrl}$path'
        ..discoveryLink = '.$path';
    });
    return new DirectoryList()
      ..kind = 'discovery#directoryList'
      ..discoveryVersion = _API_VERSION
      ..items = apiDirectory;
  }
}
