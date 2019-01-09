// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_delete_method_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

@ApiClass(version: 'v1')
class CorrectDeleteApi {
  @ApiMethod(method: 'DELETE', path: 'minimumDelete')
  VoidMessage minimumDelete() {
    return null;
  }

  @ApiMethod(name: 'namedDelete', method: 'DELETE', path: 'namedDelete')
  VoidMessage namedDelete() {
    return null;
  }

  @ApiMethod(
      name: 'fullDelete',
      method: 'DELETE',
      path: 'fullDelete',
      description: 'A method with all annotations set')
  VoidMessage fullDelete() {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectDeleteApiWithPath {
  @ApiMethod(method: 'DELETE', path: 'deleteWithString/{aString}')
  VoidMessage deleteWithString(String aString) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'deleteWithInt/{anInt}')
  VoidMessage deleteWithInt(int anInt) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'deleteWithStringInt/{aString}/{anInt}')
  VoidMessage deleteWithStringInt(String aString, int anInt) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'deleteWithIntString/{anInt}/{aString}')
  VoidMessage deleteWithIntString(String anInt, int aString) {
    return null;
  }

  @ApiMethod(
      method: 'DELETE', path: 'deleteWithStringString/{aString1}/{aString2}')
  VoidMessage deleteWithStringString(String aString1, String aString2) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'deleteWithIntInt/{anInt1}/{anInt2}')
  VoidMessage deleteWithIntInt(int anInt1, int anInt2) {
    return null;
  }

  @ApiMethod(
      method: 'DELETE',
      path: 'deleteWithIntKeywordInt/{anInt1}/keyword/{anInt2}')
  VoidMessage deleteWithIntKeywordInt(int anInt1, int anInt2) {
    return null;
  }

  @ApiMethod(
      method: 'DELETE',
      path: 'deleteWithStringKeywordString/{aString1}/keyword/{aString2}')
  VoidMessage deleteWithStringKeywordString(String aString1, String aString2) {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectDeleteApiWithQuery {
  @ApiMethod(method: 'DELETE', path: 'query1')
  VoidMessage query1({String name}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query2')
  VoidMessage query2({String qp1, String qp2}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query3')
  VoidMessage query3({int qp}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query4')
  VoidMessage query4({String qp1, int qp2}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query5')
  VoidMessage query5({int qp1, String qp2}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query6')
  VoidMessage query6({int qp1, int qp2}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query7/{pathParam}')
  VoidMessage query7(int pathParam, {int queryParam}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query8/{pathParam}')
  VoidMessage query8(String pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query9/{pathParam}')
  VoidMessage query9(int pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query10/{pathParam}')
  VoidMessage query10(String pathParam, {int queryParam}) {
    return null;
  }
}

// A lot of the failing tests are handled in api_common_method_test.dart since
// they are not specific to DELETE.
class WrongDeleteApi {
  @ApiMethod(method: 'DELETE', path: 'deleteWithMessageArg')
  VoidMessage deleteWithMessageArg(VoidMessage requestMessage) {
    return null;
  }
}

@ApiClass(version: 'v1test')
class WrongDeleteApiWithPathQuery {
  @ApiMethod(method: 'DELETE', path: 'query1')
  VoidMessage query1(String path) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query2/{queryParam}')
  VoidMessage query2(String pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query3')
  VoidMessage query3({queryParam}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query4/{queryParam}')
  VoidMessage query4({String queryParam}) {
    return null;
  }

  @ApiMethod(method: 'DELETE', path: 'query5')
  VoidMessage query5([String queryParam]) {
    return null;
  }
}

void main() {
  group('api-delete-method-correct', () {
    test('correct-delete-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectDeleteApi());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 3);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedMethods = {
        'minimumDelete': {
          'id': 'CorrectDeleteApi.minimumDelete',
          'path': 'minimumDelete',
          'httpMethod': 'DELETE',
          'parameters': {},
          'parameterOrder': []
        },
        'namedDelete': {
          'id': 'CorrectDeleteApi.namedDelete',
          'path': 'namedDelete',
          'httpMethod': 'DELETE',
          'parameters': {},
          'parameterOrder': []
        },
        'fullDelete': {
          'id': 'CorrectDeleteApi.fullDelete',
          'path': 'fullDelete',
          'httpMethod': 'DELETE',
          'description': 'A method with all annotations set',
          'parameters': {},
          'parameterOrder': []
        }
      };
      expect(json['schemas'], {});
      expect(json['methods'], expectedMethods);
    });

    test('correct-delete-api-with-path', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectDeleteApiWithPath());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 8);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedMethods = {
        'deleteWithString': {
          'id': 'CorrectDeleteApiWithPath.deleteWithString',
          'path': 'deleteWithString/{aString}',
          'httpMethod': 'DELETE',
          'parameters': {
            'aString': {
              'type': 'string',
              'description': 'Path parameter: \'aString\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['aString']
        },
        'deleteWithInt': {
          'id': 'CorrectDeleteApiWithPath.deleteWithInt',
          'path': 'deleteWithInt/{anInt}',
          'httpMethod': 'DELETE',
          'parameters': {
            'anInt': {
              'type': 'integer',
              'description': 'Path parameter: \'anInt\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['anInt']
        },
        'deleteWithStringInt': {
          'id': 'CorrectDeleteApiWithPath.deleteWithStringInt',
          'path': 'deleteWithStringInt/{aString}/{anInt}',
          'httpMethod': 'DELETE',
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
          'parameterOrder': ['aString', 'anInt']
        },
        'deleteWithIntString': {
          'id': 'CorrectDeleteApiWithPath.deleteWithIntString',
          'path': 'deleteWithIntString/{anInt}/{aString}',
          'httpMethod': 'DELETE',
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
          'parameterOrder': ['anInt', 'aString']
        },
        'deleteWithStringString': {
          'id': 'CorrectDeleteApiWithPath.deleteWithStringString',
          'path': 'deleteWithStringString/{aString1}/{aString2}',
          'httpMethod': 'DELETE',
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
          'parameterOrder': ['aString1', 'aString2']
        },
        'deleteWithIntInt': {
          'id': 'CorrectDeleteApiWithPath.deleteWithIntInt',
          'path': 'deleteWithIntInt/{anInt1}/{anInt2}',
          'httpMethod': 'DELETE',
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
          'parameterOrder': ['anInt1', 'anInt2']
        },
        'deleteWithIntKeywordInt': {
          'id': 'CorrectDeleteApiWithPath.deleteWithIntKeywordInt',
          'path': 'deleteWithIntKeywordInt/{anInt1}/keyword/{anInt2}',
          'httpMethod': 'DELETE',
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
          'parameterOrder': ['anInt1', 'anInt2']
        },
        'deleteWithStringKeywordString': {
          'id': 'CorrectDeleteApiWithPath.deleteWithStringKeywordString',
          'path': 'deleteWithStringKeywordString/{aString1}/keyword/{aString2}',
          'httpMethod': 'DELETE',
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
          'parameterOrder': ['aString1', 'aString2']
        }
      };
      expect(json['schemas'], {});
      expect(json['methods'], expectedMethods);
    });

    test('correct-delete-api-with-query', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectDeleteApiWithQuery());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 10);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedMethods = {
        'query1': {
          'id': 'CorrectDeleteApiWithQuery.query1',
          'path': 'query1',
          'httpMethod': 'DELETE',
          'parameters': {
            'name': {
              'type': 'string',
              'description': 'Query parameter: \'name\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query2': {
          'id': 'CorrectDeleteApiWithQuery.query2',
          'path': 'query2',
          'httpMethod': 'DELETE',
          'parameters': {
            'qp1': {
              'type': 'string',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'string',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query3': {
          'id': 'CorrectDeleteApiWithQuery.query3',
          'path': 'query3',
          'httpMethod': 'DELETE',
          'parameters': {
            'qp': {
              'type': 'integer',
              'description': 'Query parameter: \'qp\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query4': {
          'id': 'CorrectDeleteApiWithQuery.query4',
          'path': 'query4',
          'httpMethod': 'DELETE',
          'parameters': {
            'qp1': {
              'type': 'string',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'integer',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query5': {
          'id': 'CorrectDeleteApiWithQuery.query5',
          'path': 'query5',
          'httpMethod': 'DELETE',
          'parameters': {
            'qp1': {
              'type': 'integer',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'string',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query6': {
          'id': 'CorrectDeleteApiWithQuery.query6',
          'path': 'query6',
          'httpMethod': 'DELETE',
          'parameters': {
            'qp1': {
              'type': 'integer',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'integer',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query7': {
          'id': 'CorrectDeleteApiWithQuery.query7',
          'path': 'query7/{pathParam}',
          'httpMethod': 'DELETE',
          'parameters': {
            'pathParam': {
              'type': 'integer',
              'description': 'Path parameter: \'pathParam\'.',
              'required': true,
              'location': 'path'
            },
            'queryParam': {
              'type': 'integer',
              'description': 'Query parameter: \'queryParam\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': ['pathParam']
        },
        'query8': {
          'id': 'CorrectDeleteApiWithQuery.query8',
          'path': 'query8/{pathParam}',
          'httpMethod': 'DELETE',
          'parameters': {
            'pathParam': {
              'type': 'string',
              'description': 'Path parameter: \'pathParam\'.',
              'required': true,
              'location': 'path'
            },
            'queryParam': {
              'type': 'string',
              'description': 'Query parameter: \'queryParam\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': ['pathParam']
        },
        'query9': {
          'id': 'CorrectDeleteApiWithQuery.query9',
          'path': 'query9/{pathParam}',
          'httpMethod': 'DELETE',
          'parameters': {
            'pathParam': {
              'type': 'integer',
              'description': 'Path parameter: \'pathParam\'.',
              'required': true,
              'location': 'path'
            },
            'queryParam': {
              'type': 'string',
              'description': 'Query parameter: \'queryParam\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': ['pathParam']
        },
        'query10': {
          'id': 'CorrectDeleteApiWithQuery.query10',
          'path': 'query10/{pathParam}',
          'httpMethod': 'DELETE',
          'parameters': {
            'pathParam': {
              'type': 'string',
              'description': 'Path parameter: \'pathParam\'.',
              'required': true,
              'location': 'path'
            },
            'queryParam': {
              'type': 'integer',
              'description': 'Query parameter: \'queryParam\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': ['pathParam']
        }
      };
      expect(json['schemas'], {});
      expect(json['methods'], expectedMethods);
    });
  });

  group('api-delete-method-wrong', () {
    test('wrong-delete-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongDeleteApi());
      expect(apiCfg.methods.length, 1);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongDeleteApi: Missing required @ApiClass annotation.'),
        new ApiConfigError(
            'WrongDeleteApi: @ApiClass.version field is required.'),
        new ApiConfigError(
            'WrongDeleteApi.deleteWithMessageArg: Non-path parameter '
            '\'requestMessage\' must be a named parameter.'),
        new ApiConfigError(
            'WrongDeleteApi.deleteWithMessageArg: Query parameter '
            '\'requestMessage\' must be of type int, String or bool.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-delete-with-path-query', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongDeleteApiWithPathQuery());
      expect(apiCfg.methods.length, 5);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongDeleteApiWithPathQuery.query1: Non-path parameter \'path\' '
            'must be a named parameter.'),
        new ApiConfigError(
            'WrongDeleteApiWithPathQuery.query2: Expected method parameter '
            'with name \'queryParam\', but found parameter with name '
            '\'pathParam\'.'),
        new ApiConfigError(
            'WrongDeleteApiWithPathQuery.query3: Query parameter '
            '\'queryParam\' must be of type int, String or bool.'),
        new ApiConfigError(
            'WrongDeleteApiWithPathQuery.query4: No support for optional path '
            'parameters in API methods.'),
        new ApiConfigError(
            'WrongDeleteApiWithPathQuery.query5: Non-path parameter '
            '\'queryParam\' must be a named parameter.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
