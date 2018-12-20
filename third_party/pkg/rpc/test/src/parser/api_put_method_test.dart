// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_put_method_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

import '../test_api/messages2.dart';

@ApiClass(version: 'v1')
class CorrectPutApi {
  @ApiMethod(method: 'PUT', path: 'minimumPut')
  VoidMessage minimumPut(SimpleMessage msg) {
    return null;
  }

  @ApiMethod(name: 'namedPut', method: 'PUT', path: 'namedPut')
  VoidMessage namedPut(SimpleMessage msg) {
    return null;
  }

  @ApiMethod(name: 'returningPut', method: 'PUT', path: 'returningPut')
  SimpleMessage returningPut(SimpleMessage msg) {
    return msg;
  }

  @ApiMethod(
      name: 'fullPut',
      method: 'PUT',
      path: 'fullPut',
      description: 'A method with all annotations set')
  VoidMessage fullPut(SimpleMessage msg) {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectPutApiWithPath {
  @ApiMethod(method: 'PUT', path: 'putWithString/{aString}')
  VoidMessage putWithString(String aString, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'putWithInt/{anInt}')
  VoidMessage putWithInt(int anInt, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'putWithStringInt/{aString}/{anInt}')
  VoidMessage putWithStringInt(String aString, int anInt, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'putWithIntString/{anInt}/{aString}')
  VoidMessage putWithIntString(String anInt, int aString, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'putWithStringString/{aString1}/{aString2}')
  VoidMessage putWithStringString(
      String aString1, String aString2, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'putWithIntInt/{anInt1}/{anInt2}')
  VoidMessage putWithIntInt(int anInt1, int anInt2, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(
      method: 'PUT', path: 'putWithIntKeywordInt/{anInt1}/keyword/{anInt2}')
  VoidMessage putWithIntKeywordInt(int anInt1, int anInt2, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(
      method: 'PUT',
      path: 'putWithStringKeywordString/{aString1}/keyword/{aString2}')
  VoidMessage putWithStringKeywordString(
      String aString1, String aString2, SimpleMessage msg) {
    return null;
  }
}

// A lot of the failing tests are handled in api_common_method_test.dart since
// they are not specific to PUT.
class WrongPutApi {
  @ApiMethod(method: 'PUT', path: 'missingMessageParam')
  VoidMessage missingMessageParam() {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'invalidVoidResponse')
  void invalidVoidResponse(VoidMessage msg) {}

  @ApiMethod(method: 'PUT', path: 'dynamicMessage')
  VoidMessage dynamicMessage(message) {
    return null;
  }
}

@ApiClass(version: 'v1test')
class WrongPutApiWithPathQuery {
  @ApiMethod(method: 'PUT', path: 'missingRequestParam/{id}')
  VoidMessage missingRequestParam(String id) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'missingPathParam/{id}')
  VoidMessage missingPathParam(SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'missingPathRegExp')
  VoidMessage missingPathRegExp(String path, VoidMessage msg) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'withStringQueryParam/{pathParam}')
  VoidMessage withStringQueryParam(String pathParam, VoidMessage msg,
      {String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'withIntQueryParam/{pathParam}')
  VoidMessage withIntQueryParam(String pathParam, VoidMessage msg,
      {int queryParam}) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'withDynamicQueryParam')
  VoidMessage withDynamicQueryParam(VoidMessage msg, {queryParam}) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'withQueryNoMsg/{queryParam}')
  VoidMessage withQueryNoMsg({String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'PUT', path: 'withOptionalNoMsg')
  VoidMessage withOptionalNoMsg([String queryParam]) {
    return null;
  }
}

void main() {
  group('api-put-method-correct', () {
    test('correct-put-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectPutApi());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 4);
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
        }
      };
      var expectedMethods = {
        'minimumPut': {
          'id': 'CorrectPutApi.minimumPut',
          'path': 'minimumPut',
          'httpMethod': 'PUT',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'namedPut': {
          'id': 'CorrectPutApi.namedPut',
          'path': 'namedPut',
          'httpMethod': 'PUT',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'returningPut': {
          'id': 'CorrectPutApi.returningPut',
          'path': 'returningPut',
          'httpMethod': 'PUT',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'},
          'response': {r'$ref': 'SimpleMessage'}
        },
        'fullPut': {
          'id': 'CorrectPutApi.fullPut',
          'path': 'fullPut',
          'httpMethod': 'PUT',
          'description': 'A method with all annotations set',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'}
        }
      };
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });

    test('correct-put-api-with-path', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectPutApiWithPath());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 8);
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
        }
      };
      var expectedMethods = {
        'putWithString': {
          'id': 'CorrectPutApiWithPath.putWithString',
          'path': 'putWithString/{aString}',
          'httpMethod': 'PUT',
          'parameters': {
            'aString': {
              'type': 'string',
              'description': 'Path parameter: \'aString\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['aString'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithInt': {
          'id': 'CorrectPutApiWithPath.putWithInt',
          'path': 'putWithInt/{anInt}',
          'httpMethod': 'PUT',
          'parameters': {
            'anInt': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['anInt'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithStringInt': {
          'id': 'CorrectPutApiWithPath.putWithStringInt',
          'path': 'putWithStringInt/{aString}/{anInt}',
          'httpMethod': 'PUT',
          'parameters': {
            'aString': {
              'type': 'string',
              'description': 'Path parameter: \'aString\'.',
              'required': true,
              'location': 'path'
            },
            'anInt': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['aString', 'anInt'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithIntString': {
          'id': 'CorrectPutApiWithPath.putWithIntString',
          'path': 'putWithIntString/{anInt}/{aString}',
          'httpMethod': 'PUT',
          'parameters': {
            'anInt': {
              'type': 'string',
              'description': 'Path parameter: \'anInt\'.',
              'required': true,
              'location': 'path'
            },
            'aString': {
              'type': 'integer',
              'description': 'Path parameter: \'aString\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['anInt', 'aString'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithStringString': {
          'id': 'CorrectPutApiWithPath.putWithStringString',
          'path': 'putWithStringString/{aString1}/{aString2}',
          'httpMethod': 'PUT',
          'parameters': {
            'aString1': {
              'type': 'string',
              'description': 'Path parameter: \'aString1\'.',
              'required': true,
              'location': 'path'
            },
            'aString2': {
              'type': 'string',
              'description': 'Path parameter: \'aString2\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['aString1', 'aString2'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithIntInt': {
          'id': 'CorrectPutApiWithPath.putWithIntInt',
          'path': 'putWithIntInt/{anInt1}/{anInt2}',
          'httpMethod': 'PUT',
          'parameters': {
            'anInt1': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt1\'.',
              'required': true,
              'location': 'path'
            },
            'anInt2': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt2\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['anInt1', 'anInt2'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithIntKeywordInt': {
          'id': 'CorrectPutApiWithPath.putWithIntKeywordInt',
          'path': 'putWithIntKeywordInt/{anInt1}/keyword/{anInt2}',
          'httpMethod': 'PUT',
          'parameters': {
            'anInt1': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt1\'.',
              'required': true,
              'location': 'path'
            },
            'anInt2': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt2\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['anInt1', 'anInt2'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'putWithStringKeywordString': {
          'id': 'CorrectPutApiWithPath.putWithStringKeywordString',
          'path': 'putWithStringKeywordString/{aString1}/keyword/{aString2}',
          'httpMethod': 'PUT',
          'parameters': {
            'aString1': {
              'type': 'string',
              'description': 'Path parameter: \'aString1\'.',
              'required': true,
              'location': 'path'
            },
            'aString2': {
              'type': 'string',
              'description': 'Path parameter: \'aString2\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['aString1', 'aString2'],
          'request': {r'$ref': 'SimpleMessage'}
        }
      };
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });
  });

  group('api-put-method-wrong', () {
    test('wrong-put-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongPutApi());
      expect(apiCfg.methods.length, 3);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongPutApi: Missing required @ApiClass annotation.'),
        new ApiConfigError('WrongPutApi: @ApiClass.version field is required.'),
        new ApiConfigError(
            'WrongPutApi.missingMessageParam: API methods using PUT must '
            'have a signature of path parameters followed by one request '
            'parameter.'),
        new ApiConfigError(
            'WrongPutApi.invalidVoidResponse: API Method cannot be void, use '
            'VoidMessage as return type instead.'),
        new ApiConfigError(
            'WrongPutApi.dynamicMessage: API Method parameter has to be an '
            'instantiable class.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-put-with-path-query', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongPutApiWithPathQuery());
      expect(apiCfg.methods.length, 8);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongPutApiWithPathQuery.missingRequestParam: API methods using '
            'PUT must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.missingPathParam: Expected method '
            'parameter with name \'id\', but found parameter with name '
            '\'msg\'.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.missingPathParam: Path parameter \'id\' '
            'must be of type int, String or bool.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.missingPathParam: API methods using '
            'PUT must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.missingPathRegExp: API methods using '
            'PUT must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withStringQueryParam: API methods using '
            'PUT must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withIntQueryParam: API methods using '
            'PUT must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withDynamicQueryParam: API methods '
            'using PUT must have a signature of path parameters followed by '
            'one request parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withQueryNoMsg: No support for optional '
            'path parameters in API methods.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withQueryNoMsg: API methods using PUT '
            'must have a signature of path parameters followed by one request '
            'parameter.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withOptionalNoMsg: Request parameter '
            'cannot be optional or named.'),
        new ApiConfigError(
            'WrongPutApiWithPathQuery.withOptionalNoMsg: API Method parameter '
            'has to be an instantiable class.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
