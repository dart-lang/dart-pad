// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigResource {
  final String name;
  final Map<String, ApiConfigResource> resources;
  final List<ApiConfigMethod> methods;

  ApiConfigResource(this.name, this.resources, this.methods);

  Map<String, discovery.RestMethod> get _methodsAsDiscovery {
    var methodMap = new Map<String, discovery.RestMethod>();
    methods.forEach((method) => methodMap[method.name] = method.asDiscovery);
    return methodMap;
  }

  Map<String, discovery.RestResource> get _resourcesAsDiscovery {
    var resourceMap = new Map<String, discovery.RestResource>();
    resources.values.forEach(
        (resource) => resourceMap[resource.name] = resource.asDiscovery);
    return resourceMap;
  }

  discovery.RestResource get asDiscovery {
    var resource = new discovery.RestResource();
    resource
      ..resources = _resourcesAsDiscovery
      ..methods = _methodsAsDiscovery;
    return resource;
  }
}
