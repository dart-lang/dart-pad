// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_common_method_tests;

import 'dart:async';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

import '../test_api/messages2.dart';

@ApiClass(version: 'v1')
class CorrectMethodApiWithReturnValue {
  @ApiMethod(path: 'returnsMessage')
  SimpleMessage returnsMessage() {
    return new SimpleMessage();
  }

  @ApiMethod(path: 'returnsListOfString')
  List<String> returnsListOfString() {
    return ['foo'];
  }

  @ApiMethod(path: 'returnsListOfInt')
  List<int> returnsListOfInt() {
    return [42];
  }

  @ApiMethod(path: 'returnsListOfMessage')
  List<SimpleMessage> returnsListOfMessage() {
    return [new SimpleMessage()];
  }

  @ApiMethod(path: 'returnsMapOfString')
  Map<String, String> returnsMapOfString() {
    return {'foo': 'bar'};
  }

  @ApiMethod(path: 'returnsMapOfInt')
  Map<String, int> returnsMapOfInt() {
    return {'foo': 42};
  }

  @ApiMethod(path: 'returnsMapOfMessage')
  Map<String, SimpleMessage> returnsMapOfMessage() {
    return {'foo': new SimpleMessage()};
  }
}

@ApiClass(version: 'v1')
class CorrectMethodApiWithFutureReturnValue {
  @ApiMethod(path: 'returnsMessage')
  Future<SimpleMessage> returnsMessage() {
    return new Future.value(new SimpleMessage());
  }

  @ApiMethod(path: 'returnsListOfString')
  Future<List<String>> returnsListOfString() {
    return new Future.value(['foo']);
  }

  @ApiMethod(path: 'returnsListOfInt')
  Future<List<int>> returnsListOfInt() {
    return new Future.value([42]);
  }

  @ApiMethod(path: 'returnsListOfMessage')
  Future<List<SimpleMessage>> returnsListOfMessage() {
    return new Future.value([new SimpleMessage()]);
  }

  @ApiMethod(path: 'returnsMapOfString')
  Future<Map<String, String>> returnsMapOfString() {
    return new Future.value({'foo': 'bar'});
  }

  @ApiMethod(path: 'returnsMapOfInt')
  Future<Map<String, int>> returnsMapOfInt() {
    return new Future.value({'foo': 42});
  }

  @ApiMethod(path: 'returnsMapOfMessage')
  Future<Map<String, SimpleMessage>> returnsMapOfMessage() {
    return new Future.value({'foo': new SimpleMessage()});
  }
}

@ApiClass(version: 'v1')
class CorrectMethodApiListMap {
  @ApiMethod(path: 'returnsList')
  List<String> test1() {
    return ['foo', 'bar'];
  }

  @ApiMethod(path: 'takesList', method: 'POST')
  VoidMessage test2(List<String> request) {
    return null;
  }

  @ApiMethod(path: 'returnsMap')
  Map<String, int> test3() {
    return {'foo': 4, 'bar': 2};
  }

  @ApiMethod(path: 'takesMap', method: 'POST')
  VoidMessage test4(Map<String, int> request) {
    return null;
  }

  @ApiMethod(path: 'takesMapOfList', method: 'POST')
  List<Map<String, bool>> test5(Map<String, List<int>> request) {
    return null;
  }

  @ApiMethod(path: 'takeListOfList', method: 'POST')
  List<List<bool>> test6(List<List<int>> request) {
    return null;
  }

  @ApiMethod(path: 'takeMapOfMap', method: 'POST')
  Map<String, Map<String, bool>> test7(Map<String, Map<String, int>> request) {
    return null;
  }
}

class WrongMethodApi {
  @ApiMethod(path: 'invalidMethod', method: 'Invalid_Http_Method')
  VoidMessage invalidHttpMethod() {
    return null;
  }

  @ApiMethod()
  VoidMessage noPath() {
    return null;
  }

  @ApiMethod(name: 'noPath')
  VoidMessage nameNoPath() {
    return null;
  }

  @ApiMethod(path: '/invalidPath')
  VoidMessage invalidPath() {
    return null;
  }
}

class WrongMethodApiWithPathParam {
  @ApiMethod(path: 'missingPathParam')
  VoidMessage missingPathParam(String missing) {
    return null;
  }

  @ApiMethod(path: 'missingMethodParam/{id}')
  VoidMessage missingMethodParam() {
    return null;
  }

  @ApiMethod(path: 'mismatchMethodParam/{aMessage}')
  VoidMessage mismatchMethodParam(SimpleMessage aMessage) {
    return null;
  }
}

class WrongMethodApiWithReturnValue {
  @ApiMethod(path: 'invalidResponseVoid')
  void invalidResponseVoid() {}

  @ApiMethod(path: 'invalidResponseString')
  String invalidResponseString() {
    return '';
  }

  @ApiMethod(path: 'invalidResponseBool')
  bool invalidResponseBool() {
    return true;
  }

  @ApiMethod(path: 'invalidResponseFutureBool')
  Future<bool> invalidResponseFutureBool() {
    return new Future.value(true);
  }

  @ApiMethod(path: 'invalidResponseFutureDynamic')
  Future invalidResponseFutureDynamic() {
    return new Future.value(true);
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiList {
  @ApiMethod(path: 'returnsUnboundList')
  List test1() {
    return ['foo', 'bar'];
  }

  @ApiMethod(path: 'takesUnboundList', method: 'POST')
  VoidMessage test2(List request) {
    return null;
  }

  @ApiMethod(path: 'returnsDynamicList')
  List<dynamic> test3() {
    return ['foo', 'bar'];
  }

  @ApiMethod(path: 'takesDynamicList', method: 'POST')
  VoidMessage test4(List<dynamic> request) {
    return null;
  }

  @ApiMethod(path: 'takesListOfList', method: 'POST')
  VoidMessage test5(List<List> request) {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiMap {
  @ApiMethod(path: 'returnsUnboundMap')
  Map test1() {
    return {'foo': 4, 'bar': 2};
  }

  @ApiMethod(path: 'takesUnboundMap', method: 'POST')
  VoidMessage test2(Map request) {
    return null;
  }

  @ApiMethod(path: 'returnsDynamicMap')
  Map<String, dynamic> test3() {
    return {'foo': 4, 'bar': 2};
  }

  @ApiMethod(path: 'takesDynamicMap', method: 'POST')
  VoidMessage test4(Map<String, dynamic> request) {
    return null;
  }

  @ApiMethod(path: 'returnsInvalidKeyMap')
  Map<int, String> test5() {
    return {3: 'foo', 2: 'bar'};
  }

  @ApiMethod(path: 'takesInvalidKeyMap', method: 'POST')
  VoidMessage test6(Map<int, String> request) {
    return null;
  }

  @ApiMethod(path: 'takesMapOfMap', method: 'POST')
  VoidMessage test7(Map<int, Map> request) {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths1 {
  @ApiMethod(path: 'test1')
  VoidMessage method1a() {
    return null;
  }

  @ApiMethod(path: 'test1')
  VoidMessage method1b() {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths2 {
  @ApiMethod(path: 'test2/{path}')
  VoidMessage method2a(String path) {
    return null;
  }

  @ApiMethod(path: 'test2/path')
  VoidMessage method2b() {
    return null;
  }

  @ApiMethod(path: 'test2/other')
  VoidMessage method2c() {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths3 {
  @ApiMethod(path: 'test3/path')
  VoidMessage method3a() {
    return null;
  }

  @ApiMethod(path: 'test3/{path}')
  VoidMessage method3b(String path) {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths4 {
  @ApiMethod(path: 'test4/{path}')
  VoidMessage method4a(String path) {
    return null;
  }

  @ApiMethod(path: 'test4/{other}')
  VoidMessage method4b(String other) {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths5 {
  @ApiMethod(path: 'test5/other/some')
  VoidMessage method5a() {
    return null;
  }

  @ApiMethod(path: 'test5/{other}/some')
  VoidMessage method5b(String other) {
    return null;
  }

  @ApiMethod(path: 'test5/other/{some}')
  VoidMessage method5c(String some) {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths6 {
  @ApiMethod(path: 'test6/{other}/some')
  VoidMessage method6a(String other) {
    return null;
  }

  @ApiMethod(path: 'test6/other/some')
  VoidMessage method6b() {
    return null;
  }

  @ApiMethod(path: 'test6/other/{some}')
  VoidMessage method6c(String some) {
    return null;
  }
}

@ApiClass(version: 'v1')
class WrongMethodApiAmbiguousPaths7 {
  @ApiMethod(path: 'test7/other/{some}')
  VoidMessage method7a(String some) {
    return null;
  }

  @ApiMethod(path: 'test7/{other}/some')
  VoidMessage method7b(String other) {
    return null;
  }

  @ApiMethod(path: 'test7/other/some')
  VoidMessage method7c() {
    return null;
  }

  @ApiMethod(path: 'test7/{another}/some')
  VoidMessage method7d(String another) {
    return null;
  }

  @ApiMethod(path: 'test7/{other}/{some}')
  VoidMessage method7e(String other, String some) {
    return null;
  }

  @ApiMethod(path: 'test7/{another}/{someother}')
  VoidMessage method7f(String another, String someother) {
    return null;
  }
}

void main() {
  group('api-common-method-correct', () {
    test('correct-method-with-return', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectMethodApiWithReturnValue());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 7);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedSchemas = {
        'SimpleMessage': {
          'id': 'SimpleMessage',
          'type': 'object',
          'properties': {
            'aString': {'type': 'string'},
            'anInt': {'type': 'integer', 'format': 'int32'},
            'aBool': {'type': 'boolean'}
          }
        },
        'ListOfString': {
          'id': 'ListOfString',
          'type': 'array',
          'items': {'type': 'string'}
        },
        'ListOfint': {
          'id': 'ListOfint',
          'type': 'array',
          'items': {'type': 'integer', 'format': 'int32'}
        },
        'ListOfSimpleMessage': {
          'id': 'ListOfSimpleMessage',
          'type': 'array',
          'items': {r'$ref': 'SimpleMessage'}
        },
        'MapOfString': {
          'id': 'MapOfString',
          'type': 'object',
          'additionalProperties': {'type': 'string'}
        },
        'MapOfint': {
          'id': 'MapOfint',
          'type': 'object',
          'additionalProperties': {'type': 'integer', 'format': 'int32'}
        },
        'MapOfSimpleMessage': {
          'id': 'MapOfSimpleMessage',
          'type': 'object',
          'additionalProperties': {r'$ref': 'SimpleMessage'}
        }
      };
      var expectedMethods = {
        'returnsMessage': {
          'id': 'CorrectMethodApiWithReturnValue.returnsMessage',
          'path': 'returnsMessage',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'SimpleMessage'}
        },
        'returnsListOfString': {
          'id': 'CorrectMethodApiWithReturnValue.returnsListOfString',
          'path': 'returnsListOfString',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'ListOfString'}
        },
        'returnsListOfInt': {
          'id': 'CorrectMethodApiWithReturnValue.returnsListOfInt',
          'path': 'returnsListOfInt',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'ListOfint'}
        },
        'returnsListOfMessage': {
          'id': 'CorrectMethodApiWithReturnValue.returnsListOfMessage',
          'path': 'returnsListOfMessage',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'ListOfSimpleMessage'}
        },
        'returnsMapOfString': {
          'id': 'CorrectMethodApiWithReturnValue.returnsMapOfString',
          'path': 'returnsMapOfString',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'MapOfString'}
        },
        'returnsMapOfInt': {
          'id': 'CorrectMethodApiWithReturnValue.returnsMapOfInt',
          'path': 'returnsMapOfInt',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'MapOfint'}
        },
        'returnsMapOfMessage': {
          'id': 'CorrectMethodApiWithReturnValue.returnsMapOfMessage',
          'path': 'returnsMapOfMessage',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'MapOfSimpleMessage'}
        }
      };
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);

      // Perform the same test but this time with the return values being
      // wrapped in futures. We create a new parser since the old one still
      // contains the methods and schemas for the first api.
      parser = new ApiParser();
      apiCfg = parser.parse(new CorrectMethodApiWithFutureReturnValue());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 7);
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });

    test('correct-method-list-map', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new CorrectMethodApiListMap());
      expect(parser.isValid, isTrue);
      var expectedSchemas = {
        'ListOfString': {
          'id': 'ListOfString',
          'type': 'array',
          'items': {'type': 'string'}
        },
        'MapOfint': {
          'id': 'MapOfint',
          'type': 'object',
          'additionalProperties': {'type': 'integer', 'format': 'int32'}
        },
        'MapOfListOfint': {
          'id': 'MapOfListOfint',
          'type': 'object',
          'additionalProperties': {
            'type': 'array',
            'items': {'type': 'integer', 'format': 'int32'}
          }
        },
        'ListOfMapOfbool': {
          'id': 'ListOfMapOfbool',
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': {'type': 'boolean'}
          }
        },
        'ListOfListOfint': {
          'id': 'ListOfListOfint',
          'type': 'array',
          'items': {
            'type': 'array',
            'items': {'type': 'integer', 'format': 'int32'}
          }
        },
        'ListOfListOfbool': {
          'id': 'ListOfListOfbool',
          'type': 'array',
          'items': {
            'type': 'array',
            'items': {'type': 'boolean'}
          }
        },
        'MapOfMapOfint': {
          'id': 'MapOfMapOfint',
          'type': 'object',
          'additionalProperties': {
            'type': 'object',
            'additionalProperties': {'type': 'integer', 'format': 'int32'}
          }
        },
        'MapOfMapOfbool': {
          'id': 'MapOfMapOfbool',
          'type': 'object',
          'additionalProperties': {
            'type': 'object',
            'additionalProperties': {'type': 'boolean'}
          }
        }
      };
      var expectedMethods = {
        'test1': {
          'id': 'CorrectMethodApiListMap.test1',
          'path': 'returnsList',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'ListOfString'}
        },
        'test2': {
          'id': 'CorrectMethodApiListMap.test2',
          'path': 'takesList',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'ListOfString'}
        },
        'test3': {
          'id': 'CorrectMethodApiListMap.test3',
          'path': 'returnsMap',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {r'$ref': 'MapOfint'}
        },
        'test4': {
          'id': 'CorrectMethodApiListMap.test4',
          'path': 'takesMap',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'MapOfint'}
        },
        'test5': {
          'id': 'CorrectMethodApiListMap.test5',
          'path': 'takesMapOfList',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'MapOfListOfint'},
          'response': {r'$ref': 'ListOfMapOfbool'}
        },
        'test6': {
          'id': 'CorrectMethodApiListMap.test6',
          'path': 'takeListOfList',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'ListOfListOfint'},
          'response': {r'$ref': 'ListOfListOfbool'}
        },
        'test7': {
          'id': 'CorrectMethodApiListMap.test7',
          'path': 'takeMapOfMap',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'MapOfMapOfint'},
          'response': {r'$ref': 'MapOfMapOfbool'}
        }
      };
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080/', '');
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });
  });

  group('api-common-method-wrong', () {
    test('wrong-method-api', () {
      var parser = new ApiParser();
      parser.parse(new WrongMethodApi());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongMethodApi: Missing required @ApiClass annotation.'),
        new ApiConfigError(
            'WrongMethodApi: @ApiClass.version field is required.'),
        new ApiConfigError(
            'WrongMethodApi.invalidHttpMethod: Unknown HTTP method: '
            'INVALID_HTTP_METHOD.'),
        new ApiConfigError(
            'WrongMethodApi.invalidHttpMethod: API methods using '
            'INVALID_HTTP_METHOD must have a signature of path parameters '
            'followed by one request parameter.'),
        new ApiConfigError(
            'WrongMethodApi.noPath: ApiMethod.path field is required.'),
        new ApiConfigError(
            'WrongMethodApi.nameNoPath: ApiMethod.path field is required.'),
        new ApiConfigError(
            'WrongMethodApi.invalidPath: path cannot start with \'/\'.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-method-api-path-param', () {
      var parser = new ApiParser();
      parser.parse(new WrongMethodApiWithPathParam());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongMethodApiWithPathParam: Missing required @ApiClass '
            'annotation.'),
        new ApiConfigError(
            'WrongMethodApiWithPathParam: @ApiClass.version field is '
            'required.'),
        new ApiConfigError(
            'WrongMethodApiWithPathParam.missingPathParam: Non-path parameter '
            '\'missing\' must be a named parameter.'),
        new ApiConfigError(
            'WrongMethodApiWithPathParam.missingMethodParam: Missing methods '
            'parameters specified in method path: missingMethodParam/{id}.'),
        new ApiConfigError(
            'WrongMethodApiWithPathParam.mismatchMethodParam: Path parameter '
            '\'aMessage\' must be of type int, String or bool.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-method-api-return-value', () {
      var parser = new ApiParser();
      parser.parse(new WrongMethodApiWithReturnValue());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongMethodApiWithReturnValue: Missing required @ApiClass '
            'annotation.'),
        new ApiConfigError(
            'WrongMethodApiWithReturnValue: @ApiClass.version field is '
            'required.'),
        new ApiConfigError(
            'WrongMethodApiWithReturnValue.invalidResponseVoid: API Method '
            'cannot be void, use VoidMessage as return type instead.'),
        new ApiConfigError(
            'WrongMethodApiWithReturnValue.invalidResponseString: Return type: '
            'String is not a valid return type.'),
        new ApiConfigError(
            'WrongMethodApiWithReturnValue.invalidResponseBool: Return type: '
            'bool is not a valid return type.'),
        new ApiConfigError(
            'WrongMethodApiWithReturnValue.invalidResponseFutureBool: Return '
            'type: bool is not a valid return type.'),
        new ApiConfigError(
            'WrongMethodApiWithReturnValue.invalidResponseFutureDynamic: API '
            'Method return type has to be a instantiable class.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-method-api-list', () {
      var parser = new ApiParser();
      parser.parse(new WrongMethodApiList());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'ListOfdynamic: ListOfdynamicProperty: Properties cannot be of '
            'type: \'dynamic\'.'),
        new ApiConfigError(
            'ListOfdynamic: ListOfdynamicProperty: Properties cannot be of '
            'type: \'dynamic\'.'),
        new ApiConfigError('ListOfListOfdynamic: ListOfListOfdynamicProperty: '
            'Properties cannot be of type: \'dynamic\'.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-method-api-map', () {
      var parser = new ApiParser();
      parser.parse(new WrongMethodApiMap());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'MapOfdynamic: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfdynamic: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfdynamic: MapOfdynamicProperty: Properties cannot be of type: '
            '\'dynamic\'.'),
        new ApiConfigError(
            'MapOfdynamic: MapOfdynamicProperty: Properties cannot be of type: '
            '\'dynamic\'.'),
        new ApiConfigError(
            'MapOfString: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfString: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfMapOfdynamic: Maps must have keys of type \'String\'.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    List ambiguousPaths = [
      new WrongMethodApiAmbiguousPaths1(),
      1,
      new WrongMethodApiAmbiguousPaths2(),
      2,
      new WrongMethodApiAmbiguousPaths3(),
      1,
      new WrongMethodApiAmbiguousPaths4(),
      1,
      new WrongMethodApiAmbiguousPaths5(),
      3,
      new WrongMethodApiAmbiguousPaths6(),
      3,
      new WrongMethodApiAmbiguousPaths7(),
      15
    ];
    for (int i = 0; i < ambiguousPaths.length; i += 2) {
      test(ambiguousPaths[i].toString(), () {
        var parser = new ApiParser();
        ApiConfig apiConfig = parser.parse(ambiguousPaths[i]);
        expect(parser.isValid, isFalse);
        var config = apiConfig.generateDiscoveryDocument('baseUrl', '');
        expect(config.version, 'v1');
        expect(parser.errors.length, ambiguousPaths[i + 1]);
        parser.errors.forEach((ApiConfigError error) => expect(
            error.toString().contains('conflicts with existing method'),
            isTrue));
      });
    }
  });
}
