// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_get_method_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

@ApiClass(version: 'v1')
class CorrectGetApi {
  @ApiMethod(path: 'minimumGet')
  VoidMessage minimumGet() {
    return null;
  }

  @ApiMethod(name: 'namedGet', path: 'namedGet')
  VoidMessage namedGet() {
    return null;
  }

  @ApiMethod(
      name: 'fullGet',
      method: 'GET',
      path: 'fullGet',
      description: 'A method with all annotations set')
  VoidMessage fullGet() {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectGetApiWithPath {
  @ApiMethod(path: 'getWithString/{aString}')
  VoidMessage getWithString(String aString) {
    return null;
  }

  @ApiMethod(path: 'getWithInt/{anInt}')
  VoidMessage getWithInt(int anInt) {
    return null;
  }

  @ApiMethod(path: 'getWithStringInt/{aString}/{anInt}')
  VoidMessage getWithStringInt(String aString, int anInt) {
    return null;
  }

  @ApiMethod(path: 'getWithIntString/{anInt}/{aString}')
  VoidMessage getWithIntString(String anInt, int aString) {
    return null;
  }

  @ApiMethod(path: 'getWithStringString/{aString1}/{aString2}')
  VoidMessage getWithStringString(String aString1, String aString2) {
    return null;
  }

  @ApiMethod(path: 'getWithIntInt/{anInt1}/{anInt2}')
  VoidMessage getWithIntInt(int anInt1, int anInt2) {
    return null;
  }

  @ApiMethod(path: 'getWithIntKeywordInt/{anInt1}/keyword/{anInt2}')
  VoidMessage getWithIntKeywordInt(int anInt1, int anInt2) {
    return null;
  }

  @ApiMethod(path: 'getWithStringKeywordString/{aString1}/keyword/{aString2}')
  VoidMessage getWithStringKeywordString(String aString1, String aString2) {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectGetApiWithQuery {
  @ApiMethod(path: 'query1')
  VoidMessage query1({String name}) {
    return null;
  }

  @ApiMethod(path: 'query2')
  VoidMessage query2({String qp1, String qp2}) {
    return null;
  }

  @ApiMethod(path: 'query3')
  VoidMessage query3({int qp}) {
    return null;
  }

  @ApiMethod(path: 'query4')
  VoidMessage query4({String qp1, int qp2}) {
    return null;
  }

  @ApiMethod(path: 'query5')
  VoidMessage query5({int qp1, String qp2}) {
    return null;
  }

  @ApiMethod(path: 'query6')
  VoidMessage query6({int qp1, int qp2}) {
    return null;
  }

  @ApiMethod(path: 'query7/{pathParam}')
  VoidMessage query7(int pathParam, {int queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query8/{pathParam}')
  VoidMessage query8(String pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query9/{pathParam}')
  VoidMessage query9(int pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query10/{pathParam}')
  VoidMessage query10(String pathParam, {int queryParam}) {
    return null;
  }
}

// A lot of the failing tests are handled in api_common_method_test.dart since
// they are not specific to GET.
class WrongGetApi {
  @ApiMethod(path: 'getWithMessageArg')
  VoidMessage getWithMessageArg(VoidMessage requestMessage) {
    return null;
  }
}

@ApiClass(version: 'v1test')
class WrongGetApiWithPathQuery {
  @ApiMethod(path: 'query1')
  VoidMessage query1(String path) {
    return null;
  }

  @ApiMethod(path: 'query2/{queryParam}')
  VoidMessage query2(String pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query3')
  VoidMessage query3({queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query4/{queryParam}')
  VoidMessage query4({String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query5')
  VoidMessage query5([String queryParam]) {
    return null;
  }
}

void main() {
  group('api-get-method-correct', () {
    test('correct-get-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectGetApi());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 3);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedMethods = {
        'minimumGet': {
          'id': 'CorrectGetApi.minimumGet',
          'path': 'minimumGet',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': []
        },
        'namedGet': {
          'id': 'CorrectGetApi.namedGet',
          'path': 'namedGet',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': []
        },
        'fullGet': {
          'id': 'CorrectGetApi.fullGet',
          'path': 'fullGet',
          'httpMethod': 'GET',
          'description': 'A method with all annotations set',
          'parameters': {},
          'parameterOrder': []
        }
      };
      expect(json['schemas'], {});
      expect(json['methods'], expectedMethods);
    });

    test('correct-get-api-with-path', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectGetApiWithPath());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 8);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedMethods = {
        'getWithString': {
          'id': 'CorrectGetApiWithPath.getWithString',
          'path': 'getWithString/{aString}',
          'httpMethod': 'GET',
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
        'getWithInt': {
          'id': 'CorrectGetApiWithPath.getWithInt',
          'path': 'getWithInt/{anInt}',
          'httpMethod': 'GET',
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
        'getWithStringInt': {
          'id': 'CorrectGetApiWithPath.getWithStringInt',
          'path': 'getWithStringInt/{aString}/{anInt}',
          'httpMethod': 'GET',
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
        'getWithIntString': {
          'id': 'CorrectGetApiWithPath.getWithIntString',
          'path': 'getWithIntString/{anInt}/{aString}',
          'httpMethod': 'GET',
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
        'getWithStringString': {
          'id': 'CorrectGetApiWithPath.getWithStringString',
          'path': 'getWithStringString/{aString1}/{aString2}',
          'httpMethod': 'GET',
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
        'getWithIntInt': {
          'id': 'CorrectGetApiWithPath.getWithIntInt',
          'path': 'getWithIntInt/{anInt1}/{anInt2}',
          'httpMethod': 'GET',
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
        'getWithIntKeywordInt': {
          'id': 'CorrectGetApiWithPath.getWithIntKeywordInt',
          'path': 'getWithIntKeywordInt/{anInt1}/keyword/{anInt2}',
          'httpMethod': 'GET',
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
        'getWithStringKeywordString': {
          'id': 'CorrectGetApiWithPath.getWithStringKeywordString',
          'path': 'getWithStringKeywordString/{aString1}/keyword/{aString2}',
          'httpMethod': 'GET',
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

    test('correct-get-api-with-query', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectGetApiWithQuery());
      expect(parser.isValid, isTrue);
      expect(apiCfg.methods.length, 10);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedMethods = {
        'query1': {
          'id': 'CorrectGetApiWithQuery.query1',
          'path': 'query1',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query2',
          'path': 'query2',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query3',
          'path': 'query3',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query4',
          'path': 'query4',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query5',
          'path': 'query5',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query6',
          'path': 'query6',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query7',
          'path': 'query7/{pathParam}',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query8',
          'path': 'query8/{pathParam}',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query9',
          'path': 'query9/{pathParam}',
          'httpMethod': 'GET',
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
          'id': 'CorrectGetApiWithQuery.query10',
          'path': 'query10/{pathParam}',
          'httpMethod': 'GET',
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

  group('api-get-method-wrong', () {
    test('wrong-get-api', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongGetApi());
      expect(apiCfg.methods.length, 1);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongGetApi: Missing required @ApiClass annotation.'),
        new ApiConfigError('WrongGetApi: @ApiClass.version field is required.'),
        new ApiConfigError('WrongGetApi.getWithMessageArg: Non-path parameter '
            '\'requestMessage\' must be a named parameter.'),
        new ApiConfigError(
            'WrongGetApi.getWithMessageArg: Query parameter \'requestMessage\' '
            'must be of type int, String or bool.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-get-with-path-query', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongGetApiWithPathQuery());
      expect(apiCfg.methods.length, 5);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongGetApiWithPathQuery.query1: Non-path parameter \'path\' must '
            'be a named parameter.'),
        new ApiConfigError(
            'WrongGetApiWithPathQuery.query2: Expected method parameter with '
            'name \'queryParam\', but found parameter with name '
            '\'pathParam\'.'),
        new ApiConfigError(
            'WrongGetApiWithPathQuery.query3: Query parameter \'queryParam\' '
            'must be of type int, String or bool.'),
        new ApiConfigError(
            'WrongGetApiWithPathQuery.query4: No support for optional path '
            'parameters in API methods.'),
        new ApiConfigError(
            'WrongGetApiWithPathQuery.query5: Non-path parameter '
            '\'queryParam\' must be a named parameter.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
