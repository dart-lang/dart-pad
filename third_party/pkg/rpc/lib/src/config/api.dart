// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfig extends ApiConfigResource {
  final String apiKey;
  final String version;
  final String title;
  final String description;

  final Map<String, ApiConfigSchema> _schemaMap;

  // Method map from {$HttpMethod$NumberOfPathSegments} to list of methods.
  // TODO: Measure method lookup and possibly change to tree structure to
  // avoid the list.
  final Map<String, List<ApiConfigMethod>> _methodMap;

  ApiConfig(
      this.apiKey,
      String name,
      this.version,
      this.title,
      this.description,
      Map<String, ApiConfigResource> resources,
      List<ApiConfigMethod> methods,
      this._schemaMap,
      this._methodMap)
      : super(name, resources, methods);

  Future<HttpApiResponse> handleHttpRequest(ParsedHttpApiRequest request) {
    final List<ApiConfigMethod> methods = _methodMap[request.methodKey];
    if (methods != null) {
      for (var method in methods) {
        // TODO: improve performance of this (measure first).
        if (method.matches(request)) {
          return method.invokeHttpRequest(request);
        }
      }
    }
    return httpErrorResponse(
        request.originalRequest,
        new NotFoundError(
            'No method found matching HTTP method: ${request.httpMethod} '
            'and url: ${request.path}.'));
  }

  Future<HttpApiResponse> handleHttpOptionsRequest(
      ParsedHttpApiRequest request) async {
    var requestedHttpMethods = request.headers['access-control-request-method'];
    List<String> allowed = [];
    // If the header value is passed as a String we split the String into a List
    // and make sure the returned values are Strings (see 'Create OPTIONS
    // response' below).
    bool valueAsString = requestedHttpMethods is String;
    if (valueAsString) {
      requestedHttpMethods = requestedHttpMethods.split(',');
    }
    assert('OPTIONS'.allMatches(request.methodKey).length == 1);
    if (requestedHttpMethods != null) {
      requestedHttpMethods.forEach((String httpMethod) {
        var methodKey =
            request.methodKey.replaceFirst('OPTIONS', httpMethod.trim());
        final List<ApiConfigMethod> methods = _methodMap[methodKey];
        if (methods != null) {
          for (var method in methods) {
            if (method.matches(request)) {
              allowed.add(httpMethod);
              break;
            }
          }
        }
      });
    }

    // Create OPTIONS response.
    var headers = new Map<String, dynamic>.from(defaultResponseHeaders);
    if (allowed.isNotEmpty) {
      var allowedMethods = valueAsString ? allowed.join(',') : allowed;
      headers[HttpHeaders.allowHeader] = allowedMethods;
      headers['access-control-allow-methods'] = allowedMethods;
      headers['access-control-allow-headers'] =
          'origin, x-requested-with, content-type, accept';
    }
    return new HttpApiResponse(HttpStatus.ok, null, headers);
  }

  discovery.RestDescription generateDiscoveryDocument(
      String baseUrl, String apiPrefix) {
    String servicePath;
    if (!baseUrl.endsWith('/')) {
      baseUrl = '$baseUrl/';
    }
    if (apiPrefix != null && apiPrefix.isNotEmpty) {
      if (apiPrefix.startsWith('/')) {
        apiPrefix = apiPrefix.substring(1);
      }
      servicePath = '$apiPrefix$apiKey/';
    } else {
      servicePath = '${apiKey.substring(1)}/';
    }
    var doc = new discovery.RestDescription();
    doc
      ..kind = 'discovery#restDescription'
      ..discoveryVersion = 'v1'
      ..id = '$name:$version'
      ..name = '$name'
      ..version = version
      ..revision = '0'
      ..protocol = 'rest'
      ..baseUrl = '$baseUrl$servicePath'
      ..basePath = '/$servicePath'
      ..rootUrl = baseUrl
      ..servicePath = servicePath
      ..parameters = {}
      ..schemas = _schemasAsDiscovery
      ..methods = _methodsAsDiscovery
      ..resources = _resourcesAsDiscovery;
    if (title != null) {
      doc.title = title;
    }
    if (description != null) {
      doc.description = description;
    }

    // Compute the etag.
    var jsonDoc = discoveryDocSchema.toResponse(doc);
    var sha1Digest = sha1.convert(utf8.encode(jsonEncode(jsonDoc)));
    doc.etag = hex.encode(sha1Digest.bytes);
    return doc;
  }

  Map<String, discovery.JsonSchema> get _schemasAsDiscovery {
    var schemas = new Map<String, discovery.JsonSchema>();
    _schemaMap.forEach((String name, ApiConfigSchema schema) {
      if (schema.containsData) {
        schemas[name] = schema.asDiscovery;
      }
    });
    return schemas;
  }

  discovery.DirectoryListItems get asDirectoryListItem {
    var item = new discovery.DirectoryListItems();
    // TODO: Support preferred, icons, and documentation link as part
    // of metadata.
    item
      ..kind = 'discovery#directoryItem'
      ..id = '$name:$version'
      ..name = name
      ..version = version
      ..preferred = true;
    if (title != null) {
      item.title = title;
    }
    if (description != null) {
      item.description = description;
    }
    return item;
  }
}
