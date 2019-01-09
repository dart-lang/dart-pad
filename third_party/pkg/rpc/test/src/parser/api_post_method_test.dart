// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_post_method_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

import '../test_api/messages2.dart';

@ApiClass(version: 'v1')
class CorrectPostApi {
  @ApiMethod(method: 'POST', path: 'minimumPost')
  VoidMessage minimumPost(SimpleMessage msg) {
    return null;
  }

  @ApiMethod(name: 'namedPost', method: 'POST', path: 'namedPost')
  VoidMessage namedPost(SimpleMessage msg) {
    return null;
  }

  @ApiMethod(name: 'returningPost', method: 'POST', path: 'returningPost')
  SimpleMessage returningPost(SimpleMessage msg) {
    return msg;
  }

  @ApiMethod(
      name: 'fullPost',
      method: 'POST',
      path: 'fullPost',
      description: 'A method with all annotations set')
  VoidMessage fullPost(SimpleMessage msg) {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectPostApiWithPath {
  @ApiMethod(method: 'POST', path: 'postWithString/{aString}')
  VoidMessage postWithString(String aString, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithInt/{anInt}')
  VoidMessage postWithInt(int anInt, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithBool/{aBool}')
  VoidMessage postWithBool(bool aBool, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithStringInt/{aString}/{anInt}')
  VoidMessage postWithStringInt(String aString, int anInt, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithIntString/{anInt}/{aString}')
  VoidMessage postWithIntString(String anInt, int aString, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithStringString/{aString1}/{aString2}')
  VoidMessage postWithStringString(
      String aString1, String aString2, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithIntInt/{anInt1}/{anInt2}')
  VoidMessage postWithIntInt(int anInt1, int anInt2, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'postWithBoolInt/{aBool}/{anInt}')
  VoidMessage postWithBoolInt(int aBool, int anInt, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(
      method: 'POST', path: 'postWithIntKeywordInt/{anInt1}/keyword/{anInt2}')
  VoidMessage postWithIntKeywordInt(int anInt1, int anInt2, SimpleMessage msg) {
    return null;
  }

  @ApiMethod(
      method: 'POST',
      path: 'postWithStringKeywordString/{aString1}/keyword/{aString2}')
  VoidMessage postWithStringKeywordString(
      String aString1, String aString2, SimpleMessage msg) {
    return null;
  }
}

// A lot of the failing tests are handled in api_common_method_test.dart since
// they are not specific to POST.
class WrongPostApi {
  @ApiMethod(method: 'POST', path: 'missingMessageParam')
  VoidMessage missingMessageParam() {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'invalidVoidResponse')
  void invalidVoidResponse(VoidMessage msg) {}

  @ApiMethod(method: 'POST', path: 'dynamicMessage')
  VoidMessage dynamicMessage(message) {
    return null;
  }
}

@ApiClass(version: 'v1test')
class WrongPostApiWithPathQuery {
  @ApiMethod(method: 'POST', path: 'missingRequestParam/{id}')
  VoidMessage missingRequestParam(String id) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'missingPathParam/{id}')
  VoidMessage missingPathParam(SimpleMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'missingPathRegExp')
  VoidMessage missingPathRegExp(String path, VoidMessage msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'withStringQueryParam/{pathParam}')
  VoidMessage withStringQueryParam(String pathParam, VoidMessage msg,
      {String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'withIntQueryParam/{pathParam}')
  VoidMessage withIntQueryParam(String pathParam, VoidMessage msg,
      {int queryParam}) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'withDynamicQueryParam')
  VoidMessage withDynamicQueryParam(VoidMessage msg, {queryParam}) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'withQueryNoMsg/{queryParam}')
  VoidMessage withQueryNoMsg({String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'withOptionalNoMsg')
  VoidMessage withOptionalNoMsg([String queryParam]) {
    return null;
  }
}

void main() {
  group('api-post-method-correct', () {
    test('correct-post-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectPostApi());
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
        'minimumPost': {
          'id': 'CorrectPostApi.minimumPost',
          'path': 'minimumPost',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'namedPost': {
          'id': 'CorrectPostApi.namedPost',
          'path': 'namedPost',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'returningPost': {
          'id': 'CorrectPostApi.returningPost',
          'path': 'returningPost',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'},
          'response': {r'$ref': 'SimpleMessage'}
        },
        'fullPost': {
          'id': 'CorrectPostApi.fullPost',
          'path': 'fullPost',
          'httpMethod': 'POST',
          'description': 'A method with all annotations set',
          'parameters': {},
          'parameterOrder': [],
          'request': {r'$ref': 'SimpleMessage'}
        }
      };
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });

    test('correct-post-api-with-path', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectPostApiWithPath());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 10);
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
        'postWithString': {
          'id': 'CorrectPostApiWithPath.postWithString',
          'path': 'postWithString/{aString}',
          'httpMethod': 'POST',
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
        'postWithInt': {
          'id': 'CorrectPostApiWithPath.postWithInt',
          'path': 'postWithInt/{anInt}',
          'httpMethod': 'POST',
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
        'postWithBool': {
          'id': 'CorrectPostApiWithPath.postWithBool',
          'path': 'postWithBool/{aBool}',
          'httpMethod': 'POST',
          'parameters': {
            'aBool': {
              'type': 'boolean',
              'description': 'Path parameter: \'aBool\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['aBool'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'postWithStringInt': {
          'id': 'CorrectPostApiWithPath.postWithStringInt',
          'path': 'postWithStringInt/{aString}/{anInt}',
          'httpMethod': 'POST',
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
        'postWithIntString': {
          'id': 'CorrectPostApiWithPath.postWithIntString',
          'path': 'postWithIntString/{anInt}/{aString}',
          'httpMethod': 'POST',
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
        'postWithStringString': {
          'id': 'CorrectPostApiWithPath.postWithStringString',
          'path': 'postWithStringString/{aString1}/{aString2}',
          'httpMethod': 'POST',
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
        'postWithIntInt': {
          'id': 'CorrectPostApiWithPath.postWithIntInt',
          'path': 'postWithIntInt/{anInt1}/{anInt2}',
          'httpMethod': 'POST',
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
        'postWithBoolInt': {
          'id': 'CorrectPostApiWithPath.postWithBoolInt',
          'path': 'postWithBoolInt/{aBool}/{anInt}',
          'httpMethod': 'POST',
          'parameters': {
            'aBool': {
              'type': 'integer',
              'description': 'Path parameter: \'aBool\'.',
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
          'parameterOrder': ['aBool', 'anInt'],
          'request': {r'$ref': 'SimpleMessage'}
        },
        'postWithIntKeywordInt': {
          'id': 'CorrectPostApiWithPath.postWithIntKeywordInt',
          'path': 'postWithIntKeywordInt/{anInt1}/keyword/{anInt2}',
          'httpMethod': 'POST',
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
        'postWithStringKeywordString': {
          'id': 'CorrectPostApiWithPath.postWithStringKeywordString',
          'path': 'postWithStringKeywordString/{aString1}/keyword/{aString2}',
          'httpMethod': 'POST',
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

  group('api-post-method-wrong', () {
    test('wrong-post-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongPostApi());
      expect(apiCfg.methods.length, 3);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongPostApi: Missing required @ApiClass annotation.'),
        new ApiConfigError(
            'WrongPostApi: @ApiClass.version field is required.'),
        new ApiConfigError(
            'WrongPostApi.missingMessageParam: API methods using POST must '
            'have a signature of path parameters followed by one request '
            'parameter.'),
        new ApiConfigError(
            'WrongPostApi.invalidVoidResponse: API Method cannot be void, use '
            'VoidMessage as return type instead.'),
        new ApiConfigError(
            'WrongPostApi.dynamicMessage: API Method parameter has to be an '
            'instantiable class.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-post-with-path-query', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongPostApiWithPathQuery());
      expect(apiCfg.methods.length, 8);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongPostApiWithPathQuery.missingRequestParam: API methods using '
            'POST must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.missingPathParam: Expected method '
            'parameter with name \'id\', but found parameter with name '
            '\'msg\'.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.missingPathParam: Path parameter \'id\' '
            'must be of type int, String or bool.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.missingPathParam: API methods using '
            'POST must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.missingPathRegExp: API methods using '
            'POST must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withStringQueryParam: API methods using '
            'POST must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withIntQueryParam: API methods using '
            'POST must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withDynamicQueryParam: API methods '
            'using POST must have a signature of path parameters followed by '
            'one request parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withQueryNoMsg: No support for optional '
            'path parameters in API methods.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withQueryNoMsg: API methods using POST '
            'must have a signature of path parameters followed by one request '
            'parameter.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withOptionalNoMsg: Request parameter '
            'cannot be optional or named.'),
        new ApiConfigError(
            'WrongPostApiWithPathQuery.withOptionalNoMsg: API Method parameter '
            'has to be an instantiable class.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
