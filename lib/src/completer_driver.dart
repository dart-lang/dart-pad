// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.completer_driver;

import 'dart:io' as io;
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:logging/logging.dart';

import 'package:analysis_server/src/protocol.dart';

final Logger _logger = new Logger('completer_driver');

io.Directory sourceDirectory = io.Directory.systemTemp.createTempSync('analysisServer');

// GAE configurations.
String PACKAGE_ROOT = '/app/packages';
String SDK = '/usr/lib/dart';
String SERVER_PATH = "/app/lib/src/analysis_server_server.dart";

bool NEEDS_ENABLE_ASYNC = true;

Server server;

/**
 * Type of callbacks used to process notifications.
 */
typedef void NotificationProcessor(String event, params);

Stream<bool> analysisComplete;
StreamController<bool> _onServerStatus;

Stream<Map> completionResults;
StreamController<Map> _onCompletionResults;

Stream<Map> errors;
StreamController<Map> _onErrors;

io.File f = new io.File(sourceDirectory.path + io.Platform.pathSeparator + "main.dart");
String path = f.path;

String src0 = "main() { int b = 2;  b++;   b. }";
String src1  = "main() { String a = 'test'; a. }";
int i = 30;
bool isSetup = false;
bool isSettingUp = false;

Future ensureSetup() async {
  _logger.fine("ensureSetup: SETUP $isSetup IS_SETTING_UP $isSettingUp");
  if (!isSetup && !isSettingUp) {
    return setup();
  }
  return new Future.value();
}

Future setup() async {
  _logger.fine("Setup starting");
  isSettingUp = true;

  server = new Server();

  _onServerStatus = new StreamController<bool>(sync: true);
  analysisComplete = _onServerStatus.stream.asBroadcastStream();

  _onCompletionResults = new StreamController(sync: true);
  completionResults = _onCompletionResults.stream.asBroadcastStream();

  _onErrors = new StreamController(sync: true);
  errors = _onErrors.stream.asBroadcastStream();

  _logger.fine("Server about to start");

  // Warm up target.
  await server.start();
  _logger.fine("Setver started");

  server.listenToOutput(dispatchNotification);
  server.sendServerSetSubscriptions([ServerService.STATUS]);

  _logger.fine("Server Set Subscriptions completed");

  f.writeAsStringSync("", flush: true);

  await sendAddOverlay(path, src0);
  sendAnalysisSetAnalysisRoots([sourceDirectory.path], []);
  server.sendPrioritySetSources([path]);
  isSettingUp = false;
  isSetup = true;

  _logger.fine("Setup done");

  return analysisComplete.first;

}

Future<Map> _complete(String src, int offset) async {

  await sendAddOverlay(path, src);
  await analysisComplete.first;
  await sendCompletionGetSuggestions(path, offset);

  MergeStream completionOrError = new MergeStream();
  completionOrError.add(completionResults);
  completionOrError.add(errors);

  return completionOrError.stream.first;
}

Future<Map> completeSyncy(String src, int offset) async =>
    _complete(src, offset);

//procResults(List results) {
//  return results.map((r) => r['completion']);
//}

dispatchNotification(String event, params) async {
  if (event == "server.error") {
    // Something has gone wrong with the analysis server. This request is going
    // to fail, but we need to restart the server to be able to process
    // another request
    isSetup = false;
    isSettingUp = false;

    await server.kill();
    _onErrors.add(null);
    _logger.severe("Analysis server has crashed. CRASH CRASH CRASH $event");
    return;
  }

  if (event == "server.status" && params.containsKey('analysis') &&
      !params['analysis']['isAnalyzing']) {
    _onServerStatus.add(true);
  }

  // Ignore all but the last completion result. This means that we get a
  // precise map of the completion results, rather than a partial list.
  if (event == "completion.results" && params["isLast"]) {
    _onCompletionResults.add(params);
  }
}

Future<ServerGetVersionResult> sendServerGetVersion() {
  return server.send("server.getVersion", null).then((result) {
    ResponseDecoder decoder = new ResponseDecoder(null);
    return new ServerGetVersionResult.fromJson(decoder, 'result', result);
  });
}

Future<CompletionGetSuggestionsResult> sendCompletionGetSuggestions(
    String file, int offset) {
  var params = new CompletionGetSuggestionsParams(file, offset).toJson();
  return server.send("completion.getSuggestions", params).then((result) {
    ResponseDecoder decoder = new ResponseDecoder(null);
    return new CompletionGetSuggestionsResult.fromJson(decoder, 'result', result);
  });
}

Future<AnalysisUpdateContentResult> sendAddOverlay(
    String file, String contents) {
  _logger.fine("sendAddOverlay: $file $contents");

  var overlay = new AddContentOverlay(contents);
  var params = new AnalysisUpdateContentParams({file: overlay}).toJson();

  _logger.fine("About to send analysis.updateContent");

  return server.send("analysis.updateContent", params).then((result) {
    _logger.fine("analysis.updateContent -> then");

    ResponseDecoder decoder = new ResponseDecoder(null);
    return new AnalysisUpdateContentResult.fromJson(decoder, 'result', result);
  });
}

Future sendServerShutdown() {
  return server.send("server.shutdown", null).then((result) {
    return null;
  });
}

Future sendAnalysisSetAnalysisRoots(List<String> included, List<String> excluded,
    {Map<String, String> packageRoots}) {
  var params = new AnalysisSetAnalysisRootsParams(
      included, excluded, packageRoots: packageRoots).toJson();
  return server.send("analysis.setAnalysisRoots", params);
}

/**
 * Instances of the class [Server] manage a connection to a server process, and
 * facilitate communication to and from the server.
 */
class Server {
  /**
   * Server process object, or null if server hasn't been started yet.
   */
  io.Process _process = null;

  /**
   * Commands that have been sent to the server but not yet acknowledged, and
   * the [Completer] objects which should be completed when acknowledgement is
   * received.
   */
  final HashMap<String, Completer> _pendingCommands = <String, Completer>{};

  /**
   * Number which should be used to compute the 'id' to send in the next command
   * sent to the server.
   */
  int _nextId = 0;

  /**
   * Messages which have been exchanged with the server; we buffer these
   * up until the test finishes, so that they can be examined in the debugger
   * or printed out in response to a call to [debugStdio].
   */
  final List<String> _recordedStdio = <String>[];

  /**
   * True if we are currently printing out messages exchanged with the server.
   */
  bool _debuggingStdio = true;

  /**
   * True if we've received bad data from the server, and we are aborting the
   * test.
   */
  bool _receivedBadDataFromServer = false;

  /**
   * Stopwatch that we use to generate timing information for debug output.
   */
  Stopwatch _time = new Stopwatch();

  /**
   * Future that completes when the server process exits.
   */
  Future<int> get exitCode => _process.exitCode;

  /**
   * Print out any messages exchanged with the server.  If some messages have
   * already been exchanged with the server, they are printed out immediately.
   */
  void debugStdio() {
    if (_debuggingStdio) {
      return;
    }
    _debuggingStdio = true;
    for (String line in _recordedStdio) {
      print(line);
    }
  }

  /**
   * Return a future that will complete when all commands that have been sent
   * to the server so far have been flushed to the OS buffer.
   */
  Future flushCommands() {
    return _process.stdin.flush();
  }

  /**
   * Stop the server.
   */
  Future kill() {
    debugStdio();
    _recordStdio('PROCESS FORCIBLY TERMINATED');
    _process.kill();
    return _process.exitCode;
  }

  /**
   * Start listening to output from the server, and deliver notifications to
   * [notificationProcessor].
   */
  void listenToOutput(NotificationProcessor notificationProcessor) {
    _process.stdout.transform(
        (new Utf8Codec()).decoder).transform(new LineSplitter()).listen((String line) {
      String trimmedLine = line.trim();

      _recordStdio('RECV: $trimmedLine');
      var message;
      try {
        message = JSON.decoder.convert(trimmedLine);
      } catch (exception) {
        _badDataFromServer();
        return;
      }
      Map messageAsMap = message;
      if (messageAsMap.containsKey('id')) {
        String id = message['id'];
        Completer completer = _pendingCommands[id];
        if (completer == null) {
          print ('Unexpected response from server: id=$id');
        } else {
          _pendingCommands.remove(id);
        }
        if (messageAsMap.containsKey('error')) {
          // TODO(paulberry): propagate the error info to the completer.
          completer.completeError(
              new UnimplementedError(
                  'Server responded with an error: ${JSON.encode(message)}'));
        } else {
          completer.complete(messageAsMap['result']);
        }
        // Check that the message is well-formed.  We do this after calling
        // completer.complete() or completer.completeError() so that we don't
        // stall the test in the event of an error.
        // expect(message, isResponse);
      } else {
        // Message is a notification.  It should have an event and possibly
        // params.
//        expect(messageAsMap, contains('event'));
//        expect(messageAsMap['event'], isString);
        notificationProcessor(messageAsMap['event'], messageAsMap['params']);
        // Check that the message is well-formed.  We do this after calling
        // notificationController.add() so that we don't stall the test in the
        // event of an error.
//        expect(message, isNotification);
      }
    });
    _process.stderr.transform(
        (new Utf8Codec()).decoder).transform(new LineSplitter()).listen((String line) {
      String trimmedLine = line.trim();
      _recordStdio('ERR:  $trimmedLine');
      _badDataFromServer();
    });
  }

  Future get analysisFinished {
    Completer completer = new Completer();
    StreamSubscription subscription;

    // This will only work if the caller has already subscribed to
    // SERVER_STATUS (e.g. using sendServerSetSubscriptions(['STATUS']))
    subscription = analysisComplete.listen((bool p) {
      completer.complete(p);
      subscription.cancel();
    });
    return completer.future;
  }

  /**
   * Send a command to the server.  An 'id' will be automatically assigned.
   * The returned [Future] will be completed when the server acknowledges the
   * command with a response.  If the server acknowledges the command with a
   * normal (non-error) response, the future will be completed with the 'result'
   * field from the response.  If the server acknowledges the command with an
   * error response, the future will be completed with an error.
   */
  Future send(String method, Map<String, dynamic> params) {
    _logger.fine("Server.send $method $params");

    String id = '${_nextId++}';
    Map<String, dynamic> command = <String, dynamic>{
      'id': id,
      'method': method
    };
    if (params != null) {
      command['params'] = params;
    }
    Completer completer = new Completer();
    _pendingCommands[id] = completer;
    String line = JSON.encode(command);
    _recordStdio('SEND: $line');
    _process.stdin.add(UTF8.encoder.convert("${line}\n"));
    return completer.future;
  }

  /**
   * Start the server.  If [debugServer] is `true`, the server will be started
   * with "--debug", allowing a debugger to be attached. If [profileServer] is
   * `true`, the server will be started with "--observe" and
   * "--pause-isolates-on-exit", allowing the observatory to be used.
   */
  Future start({bool debugServer: false, bool profileServer: false}) {
    if (_process != null) {
      throw new Exception('Process already started');
    }
    _time.start();
    String dartBinary = io.Platform.executable;
    /*
    String rootDir =
        findRoot(io.Platform.script.toFilePath(windows: io.Platform.isWindows));
    String serverPath = normalize(join(rootDir, 'bin', 'server.dart'));

    String serverPath =
        normalize(join(dirname(io.Platform.script.toFilePath()), 'analysis_server_server.dart'));
 */

    List<String> arguments = [];

    //arguments.add ('--port=8181');
    //arguments.add ("8181");

    if (NEEDS_ENABLE_ASYNC) arguments.add('--enable-async');
    arguments.add('-p$PACKAGE_ROOT');
    //arguments.add('--enable-vm-service=8183');
    //arguments.add('--profile');
    if (debugServer) {
      arguments.add('--debug');
    }
    if (profileServer) {
      arguments.add('--observe');
      arguments.add('--pause-isolates-on-exit');
    }
    if (io.Platform.packageRoot.isNotEmpty) {
      arguments.add('--package-root=${io.Platform.packageRoot}');
    }
    arguments.add('--checked');
    arguments.add(SERVER_PATH);

    //arguments.add ('--port');
    //arguments.add ("8182");

    arguments.add('--sdk');
    arguments.add(SDK);

    _logger.fine("Binary: $dartBinary");
    _logger.fine("Arguments: $arguments");

    return io.Process.start(dartBinary, arguments).then((io.Process process) {
      _logger.fine("io.Process.then returned");

      _process = process;
      process.exitCode.then((int code) {
        _recordStdio('TERMINATED WITH EXIT CODE $code');

        if (code != 0) {
          _badDataFromServer();
        }
      });
    });
  }

  Future sendServerSetSubscriptions(List<ServerService> subscriptions) {
    var params = new ServerSetSubscriptionsParams(subscriptions).toJson();
    return server.send("server.setSubscriptions", params);
  }

  Future sendPrioritySetSources(List<String> paths) {
    var params = new AnalysisSetPriorityFilesParams(paths).toJson();
    return server.send("analysis.setPriorityFiles", params);
  }

  /**
   * Deal with bad data received from the server.
   */
  void _badDataFromServer() {
    if (_receivedBadDataFromServer) {
      // We're already dealing with it.
      return;
    }
    _receivedBadDataFromServer = true;
    debugStdio();
    // Give the server 1 second to continue outputting bad data before we kill
    // the test.  This is helpful if the server has had an unhandled exception
    // and is outputting a stacktrace, because it ensures that we see the
    // entire stacktrace.  Use expectAsync() to prevent the test from
    // ending during this 1 second.

    /*new Future.delayed(new Duration(seconds: 1), expectAsync(() {
      fail('Bad data received from server');
    }));
  */
  }

  /**
   * Record a message that was exchanged with the server, and print it out if
   * [debugStdio] has been called.
   */
  void _recordStdio(String line) {
    _logger.fine(line);

    double elapsedTime = _time.elapsedTicks / _time.frequency;
    line = "$elapsedTime: $line";
    if (_debuggingStdio) {
      print(line);
    }
    _recordedStdio.add(line);
  }
}


class MergeStream {
  final StreamController controller = new StreamController();

  Stream get stream => controller.stream;

  void add(Stream stream) {
    stream.listen(controller.add);
 }
}


