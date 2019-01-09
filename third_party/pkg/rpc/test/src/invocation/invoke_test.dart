// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_invoke_tests;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rpc/rpc.dart';
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../../test_util.dart';

File _blobFile() {
  var blobPath =
      p.join(getPackageDir(), 'test/src/test_api/blob_dart_logo.png');
  return new File(blobPath);
}

// Tests for exercising the setting of default values
class DefaultValueMessage {
  @ApiProperty(defaultValue: 5)
  int anInt;

  @ApiProperty(defaultValue: true)
  bool aBool;

  @ApiProperty(defaultValue: 4.2)
  double aDouble;

  @ApiProperty(defaultValue: '1969-07-20T20:18:00.000Z')
  DateTime aDate;

  @ApiProperty(defaultValue: 'Hello World!')
  String aString;

  @ApiProperty(values: const {
    'enum_value1': 'Description of enum_value1',
    'enum_value2': 'Description of enum_value2',
    'enum_value3': 'Description of enum_value3'
  }, defaultValue: 'enum_value2')
  String anEnum;

  @ApiProperty(ignore: true)
  Type ignoredProperty;
}

const _expectedDefaultResult = const {
  'anInt': 5,
  'aBool': true,
  'aDouble': 4.2,
  'aDate': '1969-07-20T20:18:00.000Z',
  'aString': 'Hello World!',
  'anEnum': 'enum_value2'
};

class MinMaxIntMessage {
  @ApiProperty(minValue: 0, maxValue: 10)
  int aBoundedInt;
}

class Int32Message {
  int anInt;
}

class Int64Message {
  @ApiProperty(format: 'int64')
  BigInt anInt;
}

class StringMessage {
  String aString;
}

class InheritanceBaseClass {
  String stringFromBase = 'default from base';
}

@ApiMessage(includeSuper: true)
class InheritanceChildClassBaseIncluded extends InheritanceBaseClass {
  String stringFromChild = 'default from child, base included';
}

class InheritanceChildClassBaseExcluded extends InheritanceBaseClass {
  String stringFromChild = 'default from child, base excluded';
}

@ApiClass(version: 'v1')
class TestAPI {
  @ApiResource()
  GetAPI get = new GetAPI();

  @ApiResource()
  DeleteAPI delete = new DeleteAPI();

  @ApiResource()
  PostAPI post = new PostAPI();

  @ApiResource()
  PutAPI put = new PutAPI();
}

class GetAPI {
  @ApiMethod(path: 'get/simple')
  VoidMessage getSimple() {
    return null;
  }

  @ApiMethod(path: 'get/throwing')
  VoidMessage getThrowing() {
    throw new BadRequestError('No request is good enough!');
  }

  @ApiMethod(path: 'get/errors')
  VoidMessage getErrors() {
    var errors = [
      new RpcErrorDetail(
          reason: 'FailureByDesign', message: 'This is supposed to happen'),
      new RpcErrorDetail(reason: 'SecondReason', message: 'Second message')
    ];
    throw new BadRequestError('This is bad :(')..errors = errors;
  }

  // This should always fail since a method is not allowed to return null.
  @ApiMethod(path: 'get/null')
  StringMessage getNull() {
    return null;
  }

  @ApiMethod(path: 'get/hello')
  StringMessage getHello({String name}) {
    return new StringMessage()
      ..aString = 'Hello ' + (name != null ? name : 'Ghost');
  }

  @ApiMethod(path: 'get/hello/{name}')
  StringMessage getHelloWithName(String name) {
    return new StringMessage()..aString = 'Hello ' + name;
  }

  @ApiMethod(path: 'get/minmax/{value}')
  MinMaxIntMessage getMinMax(int value) {
    return new MinMaxIntMessage()..aBoundedInt = value;
  }

  @ApiMethod(path: 'get/int32/{value}')
  Int32Message getInt32(int value) {
    return new Int32Message()..anInt = value;
  }

  @ApiMethod(path: 'get/int64/{value}')
  Int64Message getInt64(String value) {
    return new Int64Message()..anInt = BigInt.parse(value);
  }

  @ApiMethod(path: 'get/response')
  VoidMessage getResponse() {
    context.responseStatusCode = HttpStatus.found;
    context.responseHeaders['Location'] = 'http://some-other-url';
    return null;
  }

  @ApiMethod(path: 'get/withCookies')
  Future<StringMessage> getWithCookies() async {
    if (context.requestCookies == null) {
      throw new BadRequestError('missing cookies');
    }
    return new StringMessage()
      ..aString = 'Received cookies: ${context.requestCookies}';
  }

  @ApiMethod(path: 'get/blob')
  Future<MediaMessage> getBlob() async {
    final file = _blobFile();
    return new MediaMessage()
      ..bytes = file.readAsBytesSync()
      ..contentType = 'image/png'
      ..updated = file.lastModifiedSync();
  }

  @ApiMethod(path: 'get/blob/extra')
  Future<MediaMessage> getBlobExtra() async {
    final file = _blobFile();
    final bytes = file.readAsBytesSync();
    final md5Hash = hex.encode(md5.convert(bytes).bytes);

    return new MediaMessage()
      ..bytes = bytes
      ..contentType = 'image/png'
      ..updated = file.lastModifiedSync()
      ..md5Hash = md5Hash
      ..metadata = {'description': 'logo'};
  }

  @ApiMethod(path: 'get/inheritanceChildClassBaseIncluded')
  Future<InheritanceChildClassBaseIncluded>
      getInheritanceChildClassBaseIncluded() async {
    return new InheritanceChildClassBaseIncluded()
      ..stringFromBase = 'From base'
      ..stringFromChild = 'From child';
  }

  @ApiMethod(path: 'get/inheritanceChildClassBaseExcluded')
  Future<InheritanceChildClassBaseExcluded>
      getInheritanceChildClassBaseExcluded() async {
    return new InheritanceChildClassBaseExcluded()
      ..stringFromBase = 'From base'
      ..stringFromChild = 'From child';
  }
}

class DeleteAPI {
  @ApiMethod(method: 'DELETE', path: 'delete/simple')
  VoidMessage deleteSimple() {
    return null;
  }
}

class PostAPI {
  // This method just returns the received message. This is used to test
  // the default values (set by the RPC package) are correctly applied.
  @ApiMethod(method: 'POST', path: 'post/identity')
  DefaultValueMessage identityPost(DefaultValueMessage message) {
    return message;
  }

  @ApiMethod(method: 'POST', path: 'post/minmax')
  MinMaxIntMessage minMaxPost(MinMaxIntMessage message) {
    assert(0 <= message.aBoundedInt && message.aBoundedInt <= 10);
    return message;
  }

  @ApiMethod(method: 'POST', path: 'post/reverseList')
  List<String> reverseListPost(List<String> request) {
    return request.reversed.toList();
  }

  @ApiMethod(method: 'POST', path: 'post/add/{resource}/size/{id}')
  Map<String, int> addResourcePost(
      String resource, int id, Map<String, int> existingResources) {
    // The framework guarantees the map is not null.
    assert(existingResources != null);
    existingResources[resource] = id;
    // Set the HTTP response's status code to 201 (Created).
    context.responseStatusCode = HttpStatus.created;
    return existingResources;
  }

  // Method used to test response status code override and response headers.
  @ApiMethod(method: 'POST', path: 'post/response')
  DefaultValueMessage responsePost(DefaultValueMessage message) {
    context.responseStatusCode = HttpStatus.accepted;
    context.responseHeaders['Content-type'] = 'contentType1';
    context.responseHeaders['content-Type'] = 'contentType2';
    context.responseHeaders['my-Own-header'] = 'aHeaderValue';
    return message;
  }

  @ApiMethod(method: 'POST', path: 'post/inheritanceChildClassBaseIncluded')
  InheritanceChildClassBaseIncluded inheritanceChildClassBaseIncludedPost(
      InheritanceChildClassBaseIncluded message) {
    return message;
  }

  @ApiMethod(method: 'POST', path: 'post/inheritanceChildClassBaseExcluded')
  InheritanceChildClassBaseExcluded inheritanceChildClassBaseExcludedPost(
      InheritanceChildClassBaseExcluded message) {
    return message;
  }
}

class PutAPI {
  @ApiMethod(method: 'PUT', path: 'put/identity')
  DefaultValueMessage identityPut(DefaultValueMessage message) {
    return message;
  }
}

main() async {
  ApiServer _apiServer = new ApiServer(apiPrefix: '', prettyPrint: true);
  _apiServer.enableDiscoveryApi();
  _apiServer.addApi(new TestAPI());

  Future<HttpApiResponse> _sendRequest(String method, String path,
      {String api: 'testAPI/v1/',
      extraHeaders: const <String, dynamic>{},
      String query: '',
      body,
      List<Cookie> cookies}) {
    var headers = <String, dynamic>{'content-type': 'application/json'};
    headers.addAll(extraHeaders);
    var bodyStream;
    if ((method == 'POST' || method == 'PUT') && body != 'empty') {
      bodyStream =
          new Stream<List<int>>.fromIterable([utf8.encode(jsonEncode(body))]);
    } else {
      bodyStream = new Stream<List<int>>.fromIterable([]);
    }
    assert(query.isEmpty || query.startsWith('?'));
    Uri uri = Uri.parse('http://server/$api$path$query');
    path = '$api$path';
    var request =
        new HttpApiRequest(method, uri, headers, bodyStream, cookies: cookies);
    return _apiServer.handleHttpApiRequest(request);
  }

  Future _decodeBody(Stream<List<int>> body) async {
    if (body == null) return null;
    List<List<int>> content = await body.toList();
    assert(content.length == 1);
    return jsonDecode(utf8.decode(content.single));
  }

  group('api-invoke-get', () {
    test('simple', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/simple');
      expect(response.status, HttpStatus.noContent);
      expect(response.body, null);
    });

    test('throwing', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/throwing');
      expect(response.status, HttpStatus.badRequest);
      expect(response.exception.toString(),
          'RPC Error with status: 400 and message: No request is good enough!');
    });

    test('errors', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/errors');
      expect(response.status, HttpStatus.badRequest);
      expect(response.exception.toString(),
          'RPC Error with status: 400 and message: This is bad :(');

      // Now check that the returned JSON contains the list of errors
      var body = await _decodeBody(response.body);
      expect(body['error'].containsKey('errors'), isTrue);
      List errors = body['error']['errors'];
      expect(errors.length, 2);
      expect(errors.first, {
        'reason': 'FailureByDesign',
        'message': 'This is supposed to happen'
      });
      expect(
          errors.last, {'reason': 'SecondReason', 'message': 'Second message'});
    });

    test('null', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/null');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Method with non-void return '
          'type returned \'null\'');
    });

    test('hello-query', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/hello');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'aString': 'Hello Ghost'});
      response = await _sendRequest('GET', 'get/hello', query: '?name=John');
      expect(response.status, HttpStatus.ok);
      result = await _decodeBody(response.body);
      expect(result, {'aString': 'Hello John'});
    });

    test('hello-query-need-decode-uri', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/hello');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'aString': 'Hello Ghost'});
      response =
          await _sendRequest('GET', 'get/hello', query: '?name=John%20Cena');
      expect(response.status, HttpStatus.ok);
      result = await _decodeBody(response.body);
      expect(result, {'aString': 'Hello John Cena'});
    });

    test('hello-path', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/hello/John');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'aString': 'Hello John'});
    });

    test('hello-path-need-decode-uri', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/hello/John%20Cena');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'aString': 'Hello John Cena'});
    });

    test('minmax', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/minmax/7');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'aBoundedInt': 7});
    });

    test('invalid-minmax', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/minmax/11');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Return value \'11\' larger '
          'than maximum value \'10\'');
      response = await _sendRequest('GET', 'get/minmax/-1');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Return value \'-1\' smaller '
          'than minimum value \'0\'');
    });

    test('int32', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/int32/343');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'anInt': 343});
    });

    test('invalid-int32', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/int32/0x80000000');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Integer return value: '
          '\'2147483648\' not within the \'int32\' property range.');
      response = await _sendRequest('GET', 'get/int32/-0x80000001');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Integer return value: '
          '\'-2147483649\' not within the \'int32\' property range.');
    });

    test('int64', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/int64/0x80000000');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, {'anInt': '2147483648'});
    });

    test('invalid-int64', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/int64/0x8000000000000000');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Integer return value: '
          '\'9223372036854775808\' not within the \'int64\' property range.');
      response = await _sendRequest('GET', 'get/int64/-0x8000000000000001');
      expect(response.status, HttpStatus.internalServerError);
      expect(
          response.exception.toString(),
          'RPC Error with status: 500 and message: Integer return value: '
          '\'-9223372036854775809\' not within the \'int64\' property range.');
    });

    test('get-response', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/response');
      expect(response.status, HttpStatus.found);
      expect(
          response.headers['content-type'], 'application/json; charset=utf-8');
      expect(response.headers['location'], 'http://some-other-url');
    });

    test('get-with-cookies', () async {
      var cookies = [
        new Cookie('my-cookie', 'cookie-value'),
        new Cookie('my-other-cookie', 'other-cookie-value')..httpOnly = false
      ];
      HttpApiResponse response =
          await _sendRequest('GET', 'get/withCookies', cookies: cookies);
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      var expectedResult =
          'Received cookies: [my-cookie=cookie-value; HttpOnly, '
          'my-other-cookie=other-cookie-value]';
      expect(result['aString'], expectedResult);
    });

    test('get-blob-media', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/blob');
      expect(response.status, HttpStatus.ok);
      expect(response.headers[HttpHeaders.contentTypeHeader], 'image/png');
      final file = _blobFile();
      expect(response.headers[HttpHeaders.lastModifiedHeader],
          formatHttpDate(file.lastModifiedSync()));
      final bytes = await response.body.toList();
      expect(file.readAsBytesSync(), bytes[0]);
    });

    test('get-blob-json', () async {
      HttpApiResponse response = await _sendRequest('GET', 'get/blob?alt=json');
      expect(response.status, HttpStatus.ok);
      expect(response.headers[HttpHeaders.contentTypeHeader],
          'application/json; charset=utf-8');
      final file = _blobFile();
      final blob = await _decodeBody(response.body);
      expect(DateTime.parse(blob['updated']).toUtc(),
          file.lastModifiedSync().toUtc());
      expect(blob['bytes'], file.readAsBytesSync());
      expect(blob['contentType'], 'image/png');
    });

    test('get-blob-media-unmodified', () async {
      final file = _blobFile();
      HttpApiResponse response = await _sendRequest('GET', 'get/blob',
          extraHeaders: {
            HttpHeaders.ifModifiedSinceHeader:
                formatHttpDate(file.lastModifiedSync())
          });
      expect(response.status, HttpStatus.notModified);
      expect(response.headers[HttpHeaders.contentTypeHeader], null);
      expect(response.headers[HttpHeaders.lastModifiedHeader],
          formatHttpDate(file.lastModifiedSync()));
      expect(response.body, null);
    });

    test('get-blob-extra', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/blob/extra?alt=json');
      expect(response.status, HttpStatus.ok);
      expect(response.headers[HttpHeaders.contentTypeHeader],
          'application/json; charset=utf-8');
      final file = _blobFile();
      final blob = await _decodeBody(response.body);
      expect(DateTime.parse(blob['updated']).toUtc(),
          file.lastModifiedSync().toUtc());
      expect(blob['bytes'], file.readAsBytesSync());
      expect(blob['contentType'], 'image/png');
      expect(blob['metadata'], {'description': 'logo'});
      expect(blob['md5Hash'], 'a675cb93b75d5f1656c920dceecdcb38');
    });

    test('get-inherited-child-class-base-included', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/inheritanceChildClassBaseIncluded');
      expect(response.status, HttpStatus.ok);
      expect(response.headers[HttpHeaders.contentTypeHeader],
          'application/json; charset=utf-8');
      var result = await _decodeBody(response.body);
      expect(result,
          {'stringFromBase': 'From base', 'stringFromChild': 'From child'});
    });

    test('get-inherited-child-class-base-excluded', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'get/inheritanceChildClassBaseExcluded');
      expect(response.status, HttpStatus.ok);
      expect(response.headers[HttpHeaders.contentTypeHeader],
          'application/json; charset=utf-8');
      var result = await _decodeBody(response.body);
      expect(result, {'stringFromChild': 'From child'});
    });
  });

  group('api-invoke-delete', () {
    test('simple', () async {
      HttpApiResponse response = await _sendRequest('DELETE', 'delete/simple');
      expect(response.status, HttpStatus.noContent);
      expect(response.body, null);
    });
  });

  group('api-invoke-post', () {
    test('default', () async {
      HttpApiResponse response =
          await _sendRequest('POST', 'post/identity', body: {});
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, _expectedDefaultResult);
    });
    test('minmax', () async {
      var body = {'aBoundedInt': 5};
      HttpApiResponse response =
          await _sendRequest('POST', 'post/minmax', body: body);
      expect(response.status, HttpStatus.ok);
      var resultBody = await _decodeBody(response.body);
      expect(resultBody, body);
    });
    test('minmax-outside-range', () async {
      var body = {'aBoundedInt': 11};
      HttpApiResponse response =
          await _sendRequest('POST', 'post/minmax', body: body);
      expect(response.status, HttpStatus.badRequest);
      expect(
          response.exception.toString(),
          'RPC Error with status: 400 and message: '
          'aBoundedInt needs to be <= 10');
    });
    test('minmax-invalid-type', () async {
      HttpApiResponse response =
          await _sendRequest('POST', 'post/minmax', body: [1, 2]);
      expect(response.status, HttpStatus.badRequest);
      expect(
          response.exception.toString(),
          'RPC Error with status: 400 and message: '
          'Invalid parameter: \'[1, 2]\', should be an instance of type '
          '\'MinMaxIntMessage\'.');
    });
    test('minmax-no-request', () async {
      HttpApiResponse response =
          await _sendRequest('POST', 'post/minmax', body: 'empty');
      expect(response.status, HttpStatus.badRequest);
      expect(
          response.exception.toString(),
          'RPC Error with status: 400 and message: '
          'Method \'minMaxPost\' requires an instance of MinMaxIntMessage. '
          'Passing the empty request is not supported.');
    });
    test('minmax-null', () async {
      HttpApiResponse response =
          await _sendRequest('POST', 'post/minmax', body: null);
      expect(response.status, HttpStatus.badRequest);
      expect(
          response.exception.toString(),
          'RPC Error with status: 400 and message: Invalid parameter: '
          '\'null\', should be an instance of type \'MinMaxIntMessage\'.');
    });
    test('reverse-list', () async {
      var body = ['1', '2', '3'];
      HttpApiResponse response =
          await _sendRequest('POST', 'post/reverseList', body: body);
      expect(response.status, HttpStatus.ok);
      var resultBody = await _decodeBody(response.body);
      expect(resultBody, body.reversed.toList());
    });
    test('add-resource', () async {
      HttpApiResponse response = await _sendRequest(
          'POST', 'post/add/firstResource/size/10',
          body: {});
      expect(response.status, HttpStatus.created);
      var resultBody = await _decodeBody(response.body);
      expect(resultBody, {'firstResource': 10});
      response = await _sendRequest('POST', 'post/add/secondResource/size/20',
          body: resultBody);
      expect(response.status, HttpStatus.created);
      resultBody = await _decodeBody(response.body);
      expect(resultBody, {'firstResource': 10, 'secondResource': 20});
      expect(
          response.headers['content-type'], 'application/json; charset=utf-8');
    });
    test('response-modifications', () async {
      HttpApiResponse response =
          await _sendRequest('POST', 'post/response', body: {});
      expect(response.status, HttpStatus.accepted);
      expect(response.headers['content-type'], 'contentType2');
      expect(response.headers['my-own-header'], 'aHeaderValue');
    });
    test('add-inheritance-child-class-base-included', () async {
      var objectFields = {
        'stringFromBase': 'posted string from base',
        'stringFromChild': 'posted string from child'
      };
      HttpApiResponse response = await _sendRequest(
          'POST', 'post/inheritanceChildClassBaseIncluded',
          body: objectFields);
      var resultBody = await _decodeBody(response.body);
      expect(resultBody, objectFields);
    });
    test('add-inheritance-child-class-base-excluded', () async {
      HttpApiResponse response = await _sendRequest(
          'POST', 'post/inheritanceChildClassBaseExcluded',
          body: {
            // don't expect this in the result...
            'stringFromBase': 'posted string from base',
            // ...but do expect this one in the result.
            'stringFromChild': 'posted string from child'
          });
      var resultBody = await _decodeBody(response.body);
      expect(resultBody, {'stringFromChild': 'posted string from child'});
    });
  });

  group('api-invoke-put', () {
    test('default', () async {
      HttpApiResponse response =
          await _sendRequest('PUT', 'put/identity', body: {});
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      expect(result, _expectedDefaultResult);
    });
  });

  group('api-discovery', () {
    test('api-list', () async {
      HttpApiResponse response =
          await _sendRequest('GET', 'apis', api: 'discovery/v1/');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      var expectedResult = {
        'kind': 'discovery#directoryList',
        'discoveryVersion': 'v1',
        'items': [
          {
            'kind': 'discovery#directoryItem',
            'id': 'discovery:v1',
            'name': 'discovery',
            'version': 'v1',
            'discoveryRestUrl':
                'http://server/discovery/v1/apis/discovery/v1/rest',
            'discoveryLink': './discovery/v1/apis/discovery/v1/rest',
            'preferred': true
          },
          {
            'kind': 'discovery#directoryItem',
            'id': 'testAPI:v1',
            'name': 'testAPI',
            'version': 'v1',
            'discoveryRestUrl':
                'http://server/discovery/v1/apis/testAPI/v1/rest',
            'discoveryLink': './discovery/v1/apis/testAPI/v1/rest',
            'preferred': true
          }
        ]
      };
      expect(result, expectedResult);
    });
    test('api-discovery-doc', () async {
      HttpApiResponse response = await _sendRequest(
          'GET', 'apis/testAPI/v1/rest',
          api: 'discovery/v1/');
      expect(response.status, HttpStatus.ok);
      var result = await _decodeBody(response.body);
      var expectedResult = {
        'kind': 'discovery#restDescription',
        'etag': 'd3394f493f7d47219e75f0449614c673bb2fd045',
        'discoveryVersion': 'v1',
        'id': 'testAPI:v1',
        'name': 'testAPI',
        'version': 'v1',
        'revision': '0',
        'protocol': 'rest',
        'baseUrl': 'http://server/testAPI/v1/',
        'basePath': '/testAPI/v1/',
        'rootUrl': 'http://server/',
        'servicePath': 'testAPI/v1/',
        'parameters': {},
        'schemas': {
          'StringMessage': {
            'id': 'StringMessage',
            'type': 'object',
            'properties': {
              'aString': {'type': 'string'}
            }
          },
          'MinMaxIntMessage': {
            'id': 'MinMaxIntMessage',
            'type': 'object',
            'properties': {
              'aBoundedInt': {
                'type': 'integer',
                'format': 'int32',
                'minimum': '0',
                'maximum': '10'
              }
            }
          },
          'Int32Message': {
            'id': 'Int32Message',
            'type': 'object',
            'properties': {
              'anInt': {'type': 'integer', 'format': 'int32'}
            }
          },
          'Int64Message': {
            'id': 'Int64Message',
            'type': 'object',
            'properties': {
              'anInt': {'type': 'string', 'format': 'int64'}
            }
          },
          'MediaMessage': {
            'id': 'MediaMessage',
            'type': 'object',
            'properties': {
              'bytes': {
                'type': 'array',
                'items': {'type': 'integer', 'format': 'int32'}
              },
              'updated': {'type': 'string', 'format': 'date-time'},
              'contentType': {'type': 'string'},
              'cacheControl': {'type': 'string'},
              'contentEncoding': {'type': 'string'},
              'contentLanguage': {'type': 'string'},
              'md5Hash': {'type': 'string'},
              'metadata': {
                'type': 'object',
                'additionalProperties': {'type': 'string'}
              }
            }
          },
          'InheritanceChildClassBaseIncluded': {
            'id': 'InheritanceChildClassBaseIncluded',
            'type': 'object',
            'properties': {
              'stringFromChild': {'type': 'string'},
              'stringFromBase': {'type': 'string'}
            }
          },
          'InheritanceChildClassBaseExcluded': {
            'id': 'InheritanceChildClassBaseExcluded',
            'type': 'object',
            'properties': {
              'stringFromChild': {'type': 'string'}
            }
          },
          'DefaultValueMessage': {
            'id': 'DefaultValueMessage',
            'type': 'object',
            'properties': {
              'anInt': {'type': 'integer', 'default': '5', 'format': 'int32'},
              'aBool': {'type': 'boolean', 'default': 'true'},
              'aDouble': {
                'type': 'number',
                'default': '4.2',
                'format': 'double'
              },
              'aDate': {
                'type': 'string',
                'default': '1969-07-20T20:18:00.000Z',
                'format': 'date-time'
              },
              'aString': {'type': 'string', 'default': 'Hello World!'},
              'anEnum': {
                'type': 'string',
                'default': 'enum_value2',
                'enum': ['enum_value1', 'enum_value2', 'enum_value3'],
                'enumDescriptions': [
                  'Description of enum_value1',
                  'Description of enum_value2',
                  'Description of enum_value3'
                ]
              }
            }
          },
          'ListOfString': {
            'id': 'ListOfString',
            'type': 'array',
            'items': {'type': 'string'}
          },
          'MapOfint': {
            'id': 'MapOfint',
            'type': 'object',
            'additionalProperties': {'type': 'integer', 'format': 'int32'}
          }
        },
        'methods': {},
        'resources': {
          'get': {
            'methods': {
              'getSimple': {
                'id': 'TestAPI.get.getSimple',
                'path': 'get/simple',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': []
              },
              'getThrowing': {
                'id': 'TestAPI.get.getThrowing',
                'path': 'get/throwing',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': []
              },
              'getErrors': {
                'id': 'TestAPI.get.getErrors',
                'path': 'get/errors',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': []
              },
              'getNull': {
                'id': 'TestAPI.get.getNull',
                'path': 'get/null',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': [],
                'response': {r'$ref': 'StringMessage'}
              },
              'getHello': {
                'id': 'TestAPI.get.getHello',
                'path': 'get/hello',
                'httpMethod': 'GET',
                'parameters': {
                  'name': {
                    'type': 'string',
                    'description': 'Query parameter: \'name\'.',
                    'required': false,
                    'location': 'query'
                  }
                },
                'parameterOrder': [],
                'response': {r'$ref': 'StringMessage'}
              },
              'getHelloWithName': {
                'id': 'TestAPI.get.getHelloWithName',
                'path': 'get/hello/{name}',
                'httpMethod': 'GET',
                'parameters': {
                  'name': {
                    'type': 'string',
                    'description': 'Path parameter: \'name\'.',
                    'required': true,
                    'location': 'path'
                  }
                },
                'parameterOrder': ['name'],
                'response': {r'$ref': 'StringMessage'}
              },
              'getMinMax': {
                'id': 'TestAPI.get.getMinMax',
                'path': 'get/minmax/{value}',
                'httpMethod': 'GET',
                'parameters': {
                  'value': {
                    'type': 'integer',
                    'description': 'Path parameter: \'value\'.',
                    'required': true,
                    'location': 'path'
                  }
                },
                'parameterOrder': ['value'],
                'response': {r'$ref': 'MinMaxIntMessage'}
              },
              'getInt32': {
                'id': 'TestAPI.get.getInt32',
                'path': 'get/int32/{value}',
                'httpMethod': 'GET',
                'parameters': {
                  'value': {
                    'type': 'integer',
                    'description': 'Path parameter: \'value\'.',
                    'required': true,
                    'location': 'path'
                  }
                },
                'parameterOrder': ['value'],
                'response': {r'$ref': 'Int32Message'}
              },
              'getInt64': {
                'id': 'TestAPI.get.getInt64',
                'path': 'get/int64/{value}',
                'httpMethod': 'GET',
                'parameters': {
                  'value': {
                    'type': 'string',
                    'description': 'Path parameter: \'value\'.',
                    'required': true,
                    'location': 'path'
                  }
                },
                'parameterOrder': ['value'],
                'response': {r'$ref': 'Int64Message'}
              },
              'getResponse': {
                'id': 'TestAPI.get.getResponse',
                'path': 'get/response',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': []
              },
              'getWithCookies': {
                'id': 'TestAPI.get.getWithCookies',
                'path': 'get/withCookies',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': [],
                'response': {r'$ref': 'StringMessage'}
              },
              'getBlob': {
                'id': 'TestAPI.get.getBlob',
                'path': 'get/blob',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': [],
                'response': {r'$ref': 'MediaMessage'},
                'supportsMediaDownload': true
              },
              'getBlobExtra': {
                'id': 'TestAPI.get.getBlobExtra',
                'path': 'get/blob/extra',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': [],
                'response': {r'$ref': 'MediaMessage'},
                'supportsMediaDownload': true
              },
              'getInheritanceChildClassBaseIncluded': {
                'id': 'TestAPI.get.getInheritanceChildClassBaseIncluded',
                'path': 'get/inheritanceChildClassBaseIncluded',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': [],
                'response': {r'$ref': 'InheritanceChildClassBaseIncluded'}
              },
              'getInheritanceChildClassBaseExcluded': {
                'id': 'TestAPI.get.getInheritanceChildClassBaseExcluded',
                'path': 'get/inheritanceChildClassBaseExcluded',
                'httpMethod': 'GET',
                'parameters': {},
                'parameterOrder': [],
                'response': {r'$ref': 'InheritanceChildClassBaseExcluded'}
              }
            },
            'resources': {}
          },
          'delete': {
            'methods': {
              'deleteSimple': {
                'id': 'TestAPI.delete.deleteSimple',
                'path': 'delete/simple',
                'httpMethod': 'DELETE',
                'parameters': {},
                'parameterOrder': []
              }
            },
            'resources': {}
          },
          'post': {
            'methods': {
              'identityPost': {
                'id': 'TestAPI.post.identityPost',
                'path': 'post/identity',
                'httpMethod': 'POST',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'DefaultValueMessage'},
                'response': {r'$ref': 'DefaultValueMessage'}
              },
              'minMaxPost': {
                'id': 'TestAPI.post.minMaxPost',
                'path': 'post/minmax',
                'httpMethod': 'POST',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'MinMaxIntMessage'},
                'response': {r'$ref': 'MinMaxIntMessage'}
              },
              'reverseListPost': {
                'id': 'TestAPI.post.reverseListPost',
                'path': 'post/reverseList',
                'httpMethod': 'POST',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'ListOfString'},
                'response': {r'$ref': 'ListOfString'}
              },
              'addResourcePost': {
                'id': 'TestAPI.post.addResourcePost',
                'path': 'post/add/{resource}/size/{id}',
                'httpMethod': 'POST',
                'parameters': {
                  'resource': {
                    'type': 'string',
                    'description': 'Path parameter: \'resource\'.',
                    'required': true,
                    'location': 'path'
                  },
                  'id': {
                    'type': 'integer',
                    'description': 'Path parameter: \'id\'.',
                    'required': true,
                    'location': 'path'
                  }
                },
                'parameterOrder': ['resource', 'id'],
                'request': {r'$ref': 'MapOfint'},
                'response': {r'$ref': 'MapOfint'}
              },
              'responsePost': {
                'id': 'TestAPI.post.responsePost',
                'path': 'post/response',
                'httpMethod': 'POST',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'DefaultValueMessage'},
                'response': {r'$ref': 'DefaultValueMessage'}
              },
              'inheritanceChildClassBaseIncludedPost': {
                'id': 'TestAPI.post.inheritanceChildClassBaseIncludedPost',
                'path': 'post/inheritanceChildClassBaseIncluded',
                'httpMethod': 'POST',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'InheritanceChildClassBaseIncluded'},
                'response': {r'$ref': 'InheritanceChildClassBaseIncluded'}
              },
              'inheritanceChildClassBaseExcludedPost': {
                'id': 'TestAPI.post.inheritanceChildClassBaseExcludedPost',
                'path': 'post/inheritanceChildClassBaseExcluded',
                'httpMethod': 'POST',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'InheritanceChildClassBaseExcluded'},
                'response': {r'$ref': 'InheritanceChildClassBaseExcluded'}
              }
            },
            'resources': {}
          },
          'put': {
            'methods': {
              'identityPut': {
                'id': 'TestAPI.put.identityPut',
                'path': 'put/identity',
                'httpMethod': 'PUT',
                'parameters': {},
                'parameterOrder': [],
                'request': {r'$ref': 'DefaultValueMessage'},
                'response': {r'$ref': 'DefaultValueMessage'}
              }
            },
            'resources': {}
          }
        }
      };
      expect(result, expectedResult);
    });
  });

  group('api-invoke-options', () {
    Map<String, dynamic> extraHeaders(dynamic methods,
            {bool asString: false}) =>
        {
          'access-control-request-method':
              asString ? methods.join(',') : methods,
          'access-control-request-headers': 'content-type'
        };

    test('invalid', () async {
      HttpApiResponse response = await _sendRequest('OPTIONS', 'get/invalid',
          extraHeaders: extraHeaders(['GET']));
      expect(response.status, HttpStatus.ok);
      expect(response.headers['access-control-allow-origin'], '*');
      expect(response.headers['access-control-allow-credentials'], 'true');
      expect(response.headers['access-control-allow-headers'], isNull);
      expect(response.headers['access-control-allow-methods'], isNull);
      expect(response.headers[HttpHeaders.allowHeader], isNull);
    });

    test('invalid-all', () {
      [true, false].forEach((methodsAsString) async {
        HttpApiResponse response = await _sendRequest('OPTIONS', 'get/invalid',
            extraHeaders: extraHeaders(['GET', 'DELETE', 'POST', 'PUT'],
                asString: methodsAsString));
        expect(response.status, HttpStatus.ok);
        expect(response.headers['access-control-allow-origin'], '*');
        expect(response.headers['access-control-allow-credentials'], 'true');
        expect(response.headers['access-control-allow-headers'], isNull);
        expect(response.headers['access-control-allow-methods'], isNull);
        expect(response.headers[HttpHeaders.allowHeader], isNull);
      });
    });

    test('all', () {
      [true, false].forEach((methodsAsString) async {
        HttpApiResponse response = await _sendRequest('OPTIONS', 'get/simple',
            extraHeaders: extraHeaders(['GET', 'POST', 'DELETE', 'PUT'],
                asString: methodsAsString));
        expect(response.status, HttpStatus.ok);
        expect(response.headers['access-control-allow-origin'], '*');
        expect(response.headers['access-control-allow-credentials'], 'true');
        expect(response.headers['access-control-allow-headers'],
            'origin, x-requested-with, content-type, accept');
        var expectedMethods = methodsAsString ? 'GET' : ['GET'];
        expect(
            response.headers['access-control-allow-methods'], expectedMethods);
        expect(response.headers[HttpHeaders.allowHeader], expectedMethods);
      });
    });

    test('all-post', () {
      [true, false].forEach((methodsAsString) async {
        HttpApiResponse response = await _sendRequest(
            'OPTIONS', 'post/identity',
            extraHeaders: extraHeaders(['GET', 'POST', 'DELETE', 'PUT'],
                asString: methodsAsString));
        expect(response.status, HttpStatus.ok);
        expect(response.headers['access-control-allow-origin'], '*');
        expect(response.headers['access-control-allow-credentials'], 'true');
        expect(response.headers['access-control-allow-headers'],
            'origin, x-requested-with, content-type, accept');
        var expectedMethods = methodsAsString ? 'POST' : ['POST'];
        expect(
            response.headers['access-control-allow-methods'], expectedMethods);
        expect(response.headers[HttpHeaders.allowHeader], expectedMethods);
      });
    });

    test('get', () async {
      HttpApiResponse response = await _sendRequest('OPTIONS', 'get/simple',
          extraHeaders: extraHeaders(['GET']));
      expect(response.status, HttpStatus.ok);
      expect(response.headers['access-control-allow-methods'], ['GET']);
      expect(response.headers[HttpHeaders.allowHeader], ['GET']);
    });

    group('api-invoke-delete', () {
      test('simple', () async {
        HttpApiResponse response = await _sendRequest(
            'OPTIONS', 'delete/simple',
            extraHeaders: extraHeaders(['DELETE']));
        expect(response.status, HttpStatus.ok);
        expect(response.headers['access-control-allow-methods'], ['DELETE']);
        expect(response.headers[HttpHeaders.allowHeader], ['DELETE']);
      });
    });

    test('post', () async {
      HttpApiResponse response = await _sendRequest('OPTIONS', 'post/identity',
          body: {}, extraHeaders: extraHeaders(['POST']));
      expect(response.status, HttpStatus.ok);
      expect(response.headers['access-control-allow-methods'], ['POST']);
      expect(response.headers[HttpHeaders.allowHeader], ['POST']);
    });

    test('put', () async {
      HttpApiResponse response = await _sendRequest('OPTIONS', 'put/identity',
          body: {}, extraHeaders: extraHeaders(['PUT']));
      expect(response.status, HttpStatus.ok);
      expect(response.headers['access-control-allow-methods'], ['PUT']);
      expect(response.headers[HttpHeaders.allowHeader], ['PUT']);
    });
  });
}
