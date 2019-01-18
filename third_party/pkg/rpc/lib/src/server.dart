// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'config.dart';
import 'errors.dart';
import 'message.dart';
import 'parser.dart';
import 'utils.dart';
import 'discovery/api.dart';
import 'discovery/config.dart';

typedef Future HttpRequestHandler(io.HttpRequest request);

/// The main class for handling all API requests.
class ApiServer {
  final String _apiPrefix;
  String _discoveryApiKey;

  Converter<Object, dynamic> _jsonToBytes;

  final Map<String, ApiConfig> _apis = {};

  ApiServer({String apiPrefix, bool prettyPrint: false})
      : _apiPrefix = apiPrefix != null ? apiPrefix : '' {
    _jsonToBytes = prettyPrint
        ? new JsonEncoder.withIndent(' ').fuse(utf8.encoder)
        : json.encoder.fuse(utf8.encoder);
  }

  /// Getter for a simple dart:io HttpRequest handler.
  HttpRequestHandler get httpRequestHandler => (io.HttpRequest request) async {
        var apiResponse;
        try {
          if (!request.uri.path.startsWith(_apiPrefix)) {
            await request.drain();
            apiResponse = new HttpApiResponse.error(
                io.HttpStatus.notImplemented,
                'Invalid request for path: ${request.uri.path}',
                null,
                null);
          } else {
            var apiRequest = new HttpApiRequest.fromHttpRequest(request);
            apiResponse = await handleHttpApiRequest(apiRequest);
          }
        } catch (error, stack) {
          var exception = error;
          if (exception is Error) {
            exception = new Exception(exception.toString());
          }
          apiResponse = new HttpApiResponse.error(
              io.HttpStatus.internalServerError,
              exception.toString(),
              exception,
              stack);
        }
        return sendApiResponse(apiResponse, request.response);
      };

  /// Add a new api to the API server.
  String addApi(api) {
    ApiParser parser = new ApiParser();
    ApiConfig apiConfig = parser.parse(api);
    if (_apis.containsKey(apiConfig.apiKey)) {
      parser.addError('API already exists with path: ${apiConfig.apiKey}.');
    }
    if (!parser.isValid) {
      throw new ApiConfigError('RPC: Failed to parse API.\n\n'
          '${apiConfig.apiKey}:\n' +
          parser.errors.join('\n') +
          '\n');
    }
    rpcLogger.info('Adding ${apiConfig.apiKey} to set of valid APIs.');
    _apis[apiConfig.apiKey] = apiConfig;
    return apiConfig.apiKey;
  }

  List<String> get apis => _apis.keys.toList();

  /// Handles the api call.
  ///
  /// It looks up the corresponding api and call the api instance to
  /// further dispatch to the correct method call.
  ///
  /// Returns a HttpApiResponse either with the result of calling the method
  /// or an error if the method wasn't found, the parameters were not matching,
  /// or if the method itself failed.
  /// Errors have the format:
  ///
  ///     {
  ///       error: {
  ///         code: <http status code>,
  ///         message: <message describing the failure>
  ///       }
  ///     }
  Future<HttpApiResponse> handleHttpApiRequest(HttpApiRequest request) async {
    var drain = true;
    var response;
    try {
      // Parse the request to compute some of the values needed to determine
      // which method to invoke.
      var parsedRequest =
          new ParsedHttpApiRequest(request, _apiPrefix, _jsonToBytes);

      // The api key is the first two path segments.
      ApiConfig api = _apis[parsedRequest.apiKey];
      if (api == null) {
        return httpErrorResponse(request,
            new NotFoundError('No API with key: ${parsedRequest.apiKey}.'));
      }
      drain = false;
      rpcLogger.info('Invoking API: ${parsedRequest.apiKey} with HTTP method: '
          '${request.httpMethod} on url: ${request.uri}.');
      if (parsedRequest.isOptions) {
        response = await api.handleHttpOptionsRequest(parsedRequest);
      } else {
        response = await api.handleHttpRequest(parsedRequest);
      }
    } catch (e, stack) {
      // This can happen if the request is invalid and cannot be parsed into a
      // ParsedHttpApiRequest or in the case of a bug in the handleHttpRequest
      // code, e.g. a null pointer exception or similar. We don't drain the
      // request body in that case since we cannot know whether the bug was
      // before or after invoking the method and we cannot drain the body twice.
      var exception = e;
      if (exception is Error) {
        exception = new Exception(e.toString());
      }
      response = httpErrorResponse(request, exception,
          stack: stack, drainRequest: drain);
    }
    return response;
  }

  void enableDiscoveryApi() {
    apis.forEach((api) =>
        rpcLogger.info('Enabling Discovery API Service for api: $api'));
    _discoveryApiKey = addApi(new DiscoveryApi(this, _apiPrefix));
  }

  void disableDiscoveryApi() {
    _apis.remove(_discoveryApiKey);
    apis.forEach((api) =>
        rpcLogger.info('Disabling Discovery API Service for api: $api'));
    _discoveryApiKey = null;
  }

  /// Returns a list containing all Discovery directory items listing
  /// information about the APIs available at this API server.
  List<DirectoryListItems> getDiscoveryDirectory() {
    if (_discoveryApiKey == null) {
      // The Discovery API has not been enabled for this ApiServer.
      throw new BadRequestError('Discovery API not enabled.');
    }
    var apiDirectory = <DirectoryListItems>[];
    _apis.values.forEach((api) => apiDirectory.add(api.asDirectoryListItem));
    return apiDirectory;
  }

  /// Returns the discovery document matching the given api key.
  RestDescription getDiscoveryDocument(String baseUrl, String apiKey) {
    if (_discoveryApiKey == null) {
      // The Discovery API has not been enabled for this ApiServer.
      throw new BadRequestError('Discovery API not enabled.');
    }
    var api = _apis[apiKey];
    if (api == null) {
      throw new NotFoundError('Discovery API \'$apiKey\' not found.');
    }
    return api.generateDiscoveryDocument(baseUrl, _apiPrefix);
  }
}

/// Helper for converting an HttpApiResponse to a HttpResponse and sending it.
Future sendApiResponse(HttpApiResponse apiResponse, io.HttpResponse response) {
  response.statusCode = apiResponse.status;
  apiResponse.headers
      .forEach((name, value) => response.headers.add(name, value));
  if (apiResponse.body != null) {
    return apiResponse.body.pipe(response);
  } else {
    return response.close();
  }
}
