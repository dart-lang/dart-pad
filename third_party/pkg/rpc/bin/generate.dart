// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:args/args.dart';
import 'package:discoveryapis_generator/clientstub_generator.dart';
import 'package:path/path.dart';

ArgParser discoveryCommandArgParser() {
  return new ArgParser()
    ..addOption('input-file',
        abbr: 'i', help: 'Dart file containing the top-level API class.')
    ..addOption('port',
        abbr: 'p',
        help: 'Port by the ApiServer serving this API.',
        defaultsTo: '8080')
    ..addOption('api-prefix',
        abbr: 'a', help: 'URL prefix used by the ApiServer serving this API.');
}

ArgParser clientCommandArgParser() {
  return new ArgParser()
    ..addOption('input-file',
        abbr: 'i', help: 'Dart file containing the top-level API class.')
    ..addOption('output-dir',
        abbr: 'o', help: 'Directory in which the client stubs are generated.')
    ..addOption('port',
        abbr: 'p',
        help: 'Port by the ApiServer serving this API.',
        defaultsTo: '8080')
    ..addOption('api-prefix',
        abbr: 'a', help: 'URL prefix used by the ApiServer serving this API.')
    ..addFlag('update-pubspec',
        abbr: 'u',
        help: 'Update the pubspec.yaml file with required dependencies. This '
            'will remove comments and might change the layout of the '
            'pubspec.yaml file.',
        defaultsTo: false);
}

ArgParser globalArgParser() {
  return new ArgParser()
    ..addCommand('discovery', discoveryCommandArgParser())
    ..addCommand('client', clientCommandArgParser())
    ..addFlag('help', abbr: 'h', help: 'Displays usage information.');
}

ArgResults parseArguments(ArgParser parser, List<String> arguments) {
  ArgResults parsedArguments;
  try {
    parsedArguments = parser.parse(arguments);
  } on FormatException catch (e) {
    dieWithUsage('Error parsing arguments:\n${e.message}\n');
  }
  return parsedArguments;
}

void dieWithUsage([String message]) {
  if (message != null) {
    print(message);
  }
  print('Usage:');
  print('The rpc client API generator has the following sub-commands:');
  print('');
  print('  discovery');
  print('  client');
  print('');
  print('The \'discovery\' subcommand generates the Discovery Document(s) for '
      'the top-level API class(es) found in the given Dart input file. '
      'It takes the following options:');
  print('');
  print(discoveryCommandArgParser().usage);
  print('');
  print('The \'client\' subcommand generates the client stub libraries for '
      'the top-level API class(es) found in the given Dart input file. '
      'It takes the following options:');
  print('');
  print(clientCommandArgParser().usage);
  print('');
  exit(1);
}

main(List<String> arguments) async {
  var parser = globalArgParser();
  var options = parseArguments(parser, arguments);
  var commandOptions = options.command;
  var subCommands = ['discovery', 'client'];

  if (options['help']) {
    dieWithUsage();
  } else if (commandOptions == null ||
      !subCommands.contains(commandOptions.name)) {
    dieWithUsage('Invalid command');
  }

  try {
    var apiFilePath = commandOptions['input-file'];
    if (apiFilePath == null) {
      dieWithUsage('Please specify the path to the Dart file containing the '
          'top-level API class (annotated with @ApiClass).');
    }
    var apiFile = new File(apiFilePath);
    if (!apiFile.existsSync()) {
      print('Cannot find API file \'$apiFilePath\'');
      exit(1);
    }
    apiFilePath = absolute(apiFile.path);
    var apiPort = int.parse(commandOptions['port']);
    var apiPrefix = commandOptions['api-prefix'];
    // Strip out leading and ending '/'.
    apiPrefix = apiPrefix == null ? '' : apiPrefix.replaceAll('/', '');
    var generator = new ClientApiGenerator(apiFilePath, apiPort, apiPrefix);
    var results;
    switch (commandOptions.name) {
      case 'discovery':
        results = await generator.generateDiscovery();
        break;
      case 'client':
        var updatePubspec = commandOptions['update-pubspec'];
        var docsWithImports = await generator.generateDiscoveryWithImports();
        // Determine which directory to place the generated client stub code.
        var clientDirectoryPath =
            _clientDirectory(apiFilePath, commandOptions['output-dir']);
        // Generate the client stub code.
        results = generateClientStubs(docsWithImports, clientDirectoryPath,
            updatePubspec: updatePubspec);
        break;
    }
    results.forEach(print);
  } on GeneratorException catch (e) {
    print(e.msg);
    exit(1);
  }
}

// Computes where to put the client stub code.
String _clientDirectory(String apiFilePath, String clientDirectoryPath) {
  // If the user specified a directory, just use it.
  if (clientDirectoryPath != null) {
    return clientDirectoryPath;
  }
  // Otherwise default to 'lib/client' in the package.
  assert(apiFilePath != null);
  var packagePath = findPackageRoot(apiFilePath);
  if (packagePath == null) {
    print('API file \'$apiFilePath\' must be within a package.');
    exit(1);
  }
  return join(packagePath, 'lib', 'client');
}

/// Class used to both generate client stub code as well as Discovery Documents.
class ClientApiGenerator {
  final int _apiPort;
  final String _apiPrefix;
  String _apiFilePath;
  String _packageDirectoryPath;

  ClientApiGenerator(String dartFilePath, this._apiPort, this._apiPrefix) {
    var apiFile = new File(dartFilePath);
    if (!apiFile.existsSync()) {
      throw new GeneratorException('Could not find file: $dartFilePath');
    }
    _apiFilePath = toUri(absolute(apiFile.path)).toString();

    // Find the package directory from where to serve the packages used by the
    // top-level API class.
    _packageDirectoryPath = findPackageRoot(_apiFilePath);
    if (_packageDirectoryPath == null) {
      throw new GeneratorException(
          'File \'$dartFilePath\' must be in a valid package.');
    }
    var packageDir = new Directory(join(_packageDirectoryPath, 'packages'));
    var packagesFile = new File(join(_packageDirectoryPath, '.packages'));
    if (!packageDir.existsSync() && !packagesFile.existsSync()) {
      throw new GeneratorException(
          'Please run \'pub get\' in your API package before running the '
          'generator.');
    }

    // Make a rudimentary check that this is not a file which is 'part of' a
    // library. If so fail, asking the user to point it at the file with the
    // `library` statement.
    var partOfRegexp = new RegExp(r'\s*part\s*of\s*(\w*)');
    apiFile.readAsLinesSync().forEach((String line) {
      var matches = partOfRegexp.matchAsPrefix(line);
      if (matches != null) {
        throw new GeneratorException('Please use the file with the `library '
            '${matches.group(1)};` statement as input file instead of the '
            '`part of` file $dartFilePath.');
      }
    });
  }

  Future<dynamic> generateDiscovery() async {
    return _withServer((HttpServer server) async {
      return await _execute(server.port, 'discovery');
    });
  }

  Future<List<DescriptionImportPair>> generateDiscoveryWithImports() async {
    return _withServer((HttpServer server) async {
      Map<String, Map<String, String>> result =
          await _execute(server.port, 'discoveryWithImports');
      // Map the result from the isolate to a list of DescriptionImportPairs.
      var descriptions = <DescriptionImportPair>[];
      result.forEach((description, importMap) {
        var diPair = new DescriptionImportPair(description, importMap);
        descriptions.add(diPair);
      });
      return descriptions;
    });
  }

  Future<dynamic> _execute(int serverPort, String cmd) async {
    // In order to import the passed in Dart API file we spawn a new isolate
    // and load the code there with the passed in file imported.
    // NOTE: We do a double isolate spawn to workaround the spawnUri method
    // being blocking, meaning we will deadlock in the current isolate if
    // called directly.
    ReceivePort messagePort = new ReceivePort();
    ReceivePort errorPort = new ReceivePort();

    closePorts() {
      messagePort.close();
      errorPort.close();
    }

    var uri = 'http://127.0.0.1:$serverPort';
    try {
      await Isolate.spawn(
          _isolateTrampoline,
          [
            uri,
            _apiFilePath,
            cmd,
            _apiPort,
            _apiPrefix,
            messagePort.sendPort,
            errorPort.sendPort
          ],
          onError: errorPort.sendPort);
    } catch (error) {
      closePorts();
      rethrow;
    }

    // If we successfully launched the isolate, we'll wait for either the
    // message or an error and take whatever comes first.
    var completer = new Completer();
    var messageSubscription, errorSubscription;
    finish(value, isError) {
      messageSubscription.cancel();
      errorSubscription.cancel();
      closePorts();
      if (isError) {
        completer.completeError(value);
      } else {
        completer.complete(value);
      }
    }

    messageSubscription = messagePort.listen((value) {
      finish(value, false);
    });
    errorSubscription = errorPort.listen((error) {
      finish(error, true);
    });
    return completer.future;
  }

  Future<T> _withServer<T>(f(HttpServer server)) async {
    Future _httpSourceLoader(HttpRequest request) async {
      var path = request.uri.path;
      if (path.contains('/packages/')) {
        File packageFile = new File(_packageDirectoryPath + path);
        request.response
          ..add(packageFile.readAsBytesSync())
          ..close();
      } else if (path.contains('.packages')) {
        // Didn't find .packages so revert to /packages/.
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      } else {
        request.response
          ..add(utf8.encode(generatorSource))
          ..close();
      }
    }

    var server = await HttpServer.bind('127.0.0.1', 0);
    try {
      server.listen(_httpSourceLoader);
      return await f(server);
    } finally {
      server.close();
    }
  }

  static Future _isolateTrampoline(List<dynamic> args) async {
    SendPort messagePort = args[5];
    SendPort errorPort = args[6];
    return await Isolate.spawnUri(
        Uri.parse(args[0]),
        <String>[
          args[1].toString(),
          args[2].toString(),
          args[3].toString(),
          args[4].toString()
        ],
        messagePort,
        onError: errorPort);
  }

  String get generatorSource {
    assert(_apiFilePath != null && _apiFilePath.isNotEmpty);
    return '''
    import 'dart:async';
    import 'dart:convert';
    import 'dart:io';
    import 'dart:mirrors';

    import 'package:rpc/rpc.dart';
    import 'package:rpc/src/parser.dart';
    import '${_apiFilePath}';

    // This main method is invoked via the spawnUri call from the generate.dart
    // ClientApiGenerator class. See the method ClientApiGenerator._execute for
    // the specifics on what arguments are passed.
    main(args, message) async {
      var sendPort = message;
      // Find the library for which to generate a client or Discovery Document.
      String apiFilePath = args[0];
      var lm = currentMirrorSystem().libraries[Uri.parse(apiFilePath)];
      if (lm == null) {
        print('Could not find a Dart library for the given input file '
              '\\'\$apiFilePath\\'. The given file must be a Dart library');
        exit(1);
      }

      // Determine whether we are generating a client stub or a Discovery
      // Document and call the respective generator method.
      var result;
      String cmd = args[1];
      int apiPort = int.parse(args[2]);
      String apiPrefix = args[3] == null ? '' : args[3];
      if (cmd == 'discoveryWithImports') {
        result = await generateDiscoveryWithImports(lm, apiPort, apiPrefix);
      } else {
        assert(cmd == 'discovery');
        result = await generateDiscovery(lm, apiPort, apiPrefix);
      }
      sendPort.send(result);
    }

    // Generate client stub code for each of the ApiClass classes found in the
    // given Library.
    Future<Map<String, Map<String, String>>> generateDiscoveryWithImports(
        LibraryMirror lm, int apiPort, String apiPrefix) async {
      var result = <String, Map<String, String>>{};
      for (var dm in lm.declarations.values) {
        var api = _validateAndCreateApiInstance(dm);
        if (api == null) continue;

        // Get the Discovery Document (We cannot use the RestDescription from
        // the parsed api below since it is a different RestDescription than the
        // one used by the discoveryapis_generator package. Instead we encode it
        // as a JSON string and decode it in the discoveryapis_generator
        // package.
        String document = await _generateDocument(api, apiPort, apiPrefix);

        // Compute map from schema (aka. message class) to Dart file location.
        var parser = new ApiParser(strict: true);
        var apiConfig = parser.parse(api);
        if (!parser.isValid) {
          throw \'RPC: Failed to parse API.\\n\\n\${apiConfig.apiKey}:\\n\' +
                 parser.errors.join(\'\\n\') + \'\\n\';
        }
        Map<String, String> importMap = {};
        parser.apiSchemas.forEach((name, schemaConfig) {
          importMap[name] =
              schemaConfig.schemaClass.location.sourceUri.toString();
        });
        result[document] = importMap;
      }
      return result;
    }

    // Generate Discovery Document(s) for all ApiClass classes found in the
    // given library.
    Future<List<String>> generateDiscovery(LibraryMirror lm,
                                           int apiPort,
                                           String apiPrefix) async {
      var result = <String>[];
      for (var dm in lm.declarations.values) {
        var api = _validateAndCreateApiInstance(dm);
        if (api == null) continue;

        String document = await _generateDocument(api, apiPort, apiPrefix);
        result.add(document);
      }
      return result;
    }

    Future<String> _generateDocument(dynamic apiInstance,
                                     int apiPort,
                                     String apiPrefix) async {
      // Create an ApiServer to use for generating the Discovery Document.
      var server = new ApiServer(apiPrefix: apiPrefix, prettyPrint: true)
          ..enableDiscoveryApi()
          ..addApi(apiInstance);
      List<String> apis = server.apis;
      assert(apis.length == 2);
      var path = '\$apiPrefix/discovery/v1/apis\${apis[1]}/rest';
      Uri uri = Uri.parse('http://localhost:\$apiPort/\$path');
      var request =
          new HttpApiRequest('GET', uri, {}, new Stream.fromIterable([]));
      HttpApiResponse response = await server.handleHttpApiRequest(request);
      return response.body.transform(utf8.decoder).join('');
    }

    // Checks if the DeclarationMirror is a class and annotated with @ApiClass.
    // If so creates an instance and returns it.
    dynamic _validateAndCreateApiInstance(DeclarationMirror dm) {
      // Determine if this declaration is an API class (e.g. a class annotated
      // with @ApiClass).
      var annotations = dm.metadata.where(
          (a) => a.reflectee.runtimeType == ApiClass).toList();

      var apiInstance;
      if (dm is ClassMirror && annotations.length == 1) {
        // We only support automatic generation of client stubs using same
        // message classes for top-level API classes with a default constructor
        // taking no arguments.
        try {
          apiInstance = dm.newInstance(new Symbol(''), []).reflectee;
        } catch (e) {
          var className = MirrorSystem.getName(dm.simpleName);
          print('Failed to create an instance of the API class '
                '\\'\$className\\'. For the generator to work the class must '
                'have a working default constructor taking no arguments.');
          exit(1);
        }
      }
      return apiInstance;
    }
  ''';
  }
}

class GeneratorException implements Exception {
  String msg;

  GeneratorException(this.msg);
}
