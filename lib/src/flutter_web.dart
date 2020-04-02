// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'sdk_manager.dart';

Logger _logger = Logger('flutter_web');

/// Handle provisioning package:flutter_web and related work.
class FlutterWebManager {
  final FlutterSdk flutterSdk;

  Directory _projectDirectory;

  bool _initedFlutterWeb = false;

  FlutterWebManager(this.flutterSdk) {
    _projectDirectory = Directory.systemTemp.createTempSync('dartpad');
    _init();
  }

  void dispose() {
    _projectDirectory.deleteSync(recursive: true);
  }

  Directory get projectDirectory => _projectDirectory;

  String get packagesFilePath => path.join(projectDirectory.path, '.packages');

  void _init() {
    // create a pubspec.yaml file
    final pubspec = createPubspec(true);
    File(path.join(_projectDirectory.path, 'pubspec.yaml'))
        .writeAsStringSync(pubspec);

    // create a .packages file
    final packagesFileContents = '''
$_samplePackageName:lib/
''';
    File(path.join(_projectDirectory.path, '.packages'))
        .writeAsStringSync(packagesFileContents);

    // and create a lib/ folder for completeness
    Directory(path.join(_projectDirectory.path, 'lib')).createSync();
  }

  Future<void> warmup() async {
    try {
      await initFlutterWeb();
    } catch (e, s) {
      _logger.warning('Error initializing flutter web', e, s);
    }
  }

  Future<void> initFlutterWeb() async {
    if (_initedFlutterWeb) {
      return;
    }

    _logger.info('creating flutter web pubspec');
    final pubspec = createPubspec(true);
    await File(path.join(_projectDirectory.path, 'pubspec.yaml'))
        .writeAsString(pubspec);

    await _runPubGet();

    _initedFlutterWeb = true;
  }

  String get summaryFilePath {
    return path.join('artifacts', 'flutter_web.dill');
  }

  static final Set<String> _flutterWebImportPrefixes = <String>{
    'package:flutter',
    'dart:ui',
  };

  bool usesFlutterWeb(Set<String> imports) {
    return imports.any((String import) {
      return _flutterWebImportPrefixes.any(
        (String prefix) => import.startsWith(prefix),
      );
    });
  }

  bool hasUnsupportedImport(Set<String> imports) {
    return getUnsupportedImport(imports) != null;
  }

  String getUnsupportedImport(Set<String> imports) {
    for (final import in imports) {
      // All dart: imports are ok;
      if (import.startsWith('dart:')) {
        continue;
      }

      // Currently we only allow flutter web imports.
      if (import.startsWith('package:')) {
        if (_flutterWebImportPrefixes
            .any((String prefix) => import.startsWith(prefix))) {
          continue;
        }

        return import;
      }

      // Don't allow file imports.
      return import;
    }

    return null;
  }

  Future<void> _runPubGet() async {
    _logger.info('running flutter pub get (${_projectDirectory.path})');

    final observatoryPort = await _findFreePort();

    // The DART_VM_OPTIONS flag is included here to override the one sent by the
    // Dart SDK during tests. Without the flag, the Flutter tool will attempt to
    // spin up its own observatory on the same port as the one already
    // instantiated by the Dart SDK running the test, causing a hang.
    //
    // The value should be an available port number.
    final result = await Process.start(
      path.join(flutterSdk.flutterBinPath, 'flutter'),
      ['pub', 'get'],
      workingDirectory: _projectDirectory.path,
      environment: {'DART_VM_OPTIONS': '--enable-vm-service=$observatoryPort'},
    );

    _logger.info('${result.stdout}'.trim());

    final code = await result.exitCode;

    if (code != 0) {
      _logger.warning('pub get failed: ${result.exitCode}');
      _logger.warning(result.stderr);

      throw 'pub get failed: ${result.exitCode}: ${result.stderr}';
    }
  }

  Future<int> _findFreePort({bool ipv6 = false}) async {
    var port = 0;
    ServerSocket serverSocket;
    final loopback =
        ipv6 ? InternetAddress.loopbackIPv6 : InternetAddress.loopbackIPv4;

    try {
      serverSocket = await ServerSocket.bind(loopback, 0);
      port = serverSocket.port;
    } on SocketException catch (e) {
      // If ipv4 loopback bind fails, try ipv6.
      if (!ipv6) {
        return _findFreePort(ipv6: true);
      }
      _logger.severe('Could not find free port for `pub get`: $e');
    } catch (e) {
      // Failures are signaled by a return value of 0 from this function.
      _logger.severe('Could not find free port for `pub get`: $e');
    } finally {
      if (serverSocket != null) {
        await serverSocket.close();
      }
    }

    return port;
  }

  static const String _samplePackageName = 'dartpad_sample';

  static String createPubspec(bool includeFlutterWeb) {
    var content = '''
name: $_samplePackageName
''';

    if (includeFlutterWeb) {
      content += '''
dependencies:
  flutter:
    sdk: flutter
  flutter_test:
    sdk: flutter
''';
    }

    return content;
  }
}
