// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around an analysis server instance
library services.analysis_server;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' as io;

import 'package:analysis_server/src/protocol.dart';
import 'package:logging/logging.dart';

import 'api_classes.dart' as api;

/**
 * Type of callbacks used to process notifications.
 */
typedef void NotificationProcessor(String event, params);

final Logger _logger = new Logger('analysis_server');

/**
 * Flag to determine wheter we should dump the communication
 * with the server to stdout.
 */
bool dumpServerMessages = false;

final _WARMUP_SRC_HTML = "import 'dart:html'; main() { int b = 2;  b++;   b. }";
final _WARMUP_SRC = "main() { int b = 2;  b++;   b. }";
final _SERVER_PATH = "bin/_analysis_server_entry.dart";

var sourceDirectory;
var mainPath;

class AnalysisServerWrapper {
  final String sdkPath;

  /// Instance to handle communication with the server.
  _Server serverConnection;

  AnalysisServerWrapper(this.sdkPath) {
    _logger.info("AnalysisServerWrapper ctor");
    sourceDirectory = io.Directory.systemTemp.createTempSync('analysisServer');
    mainPath = "${sourceDirectory.path}${io.Platform.pathSeparator}main.dart";
    serverConnection = new _Server(this.sdkPath);
  }

  Future<api.CompleteResponse> complete(String src, int offset) async {
    Future<Map> results = _completeImpl(
        {mainPath : src}, mainPath, offset);

    // Post process the result from Analysis Server.
    return results.then((Map response) {
      List<Map> results = response['results'];

      // This hack filters out of scope completions. It needs removing
      // when we have categories of completions.
      results = results.where((res) => res['relevance'] > 500).toList();

      results.sort((x, y) {
        var xRelevance = x['relevance'];
        var yRelevance = y['relevance'];
        if (xRelevance == yRelevance) {
          return x['completion'].compareTo(y['completion']);
        } else {
          return -1 * xRelevance.compareTo(yRelevance);
        }});
      return new api.CompleteResponse(
          response['replacementOffset'], response['replacementLength'],
          results);
    });
  }

  Future<api.FixesResponse> getFixes(String src, int offset) async {
    var results = _getFixesImpl(src, offset);
    return results.then((fixes) => new api.FixesResponse(fixes.fixes));
  }

  Future<api.FormatResponse> format(String src, int offset) async {
    var results = _formatImpl(src, offset);
    return results.then((EditFormatResult editResult) {
      String editSrc = src;
      List<SourceEdit> edits = editResult.edits;
      edits.sort((e1, e2) => -1 * e1.offset.compareTo(e2.offset));

      for (var edit in edits) {
        editSrc = edit.apply(editSrc);
      }
      return new api.FormatResponse(editSrc, editResult.selectionOffset);
    });
  }

  /// Cleanly shutdown the Analysis Server.
  Future shutdown() => serverConnection.sendServerShutdown();

  /// Internal implementation of the completion mechanism.
  Future<Map> _completeImpl(Map<String, String> sources,
                            String path, int offset) async {
    await serverConnection._ensureSetup();

    await serverConnection.loadSources(sources);
    await serverConnection.analysisComplete.first;
    await serverConnection.sendCompletionGetSuggestions(path, offset);

    return serverConnection.completionResults.handleError(
        (error) => throw "Completion failed").first.then((ret) async {
          await serverConnection.unloadSources(sources.keys);
          return ret;
    });
  }

  Future<EditGetFixesResult> _getFixesImpl(String src, int offset) async {
    await serverConnection._ensureSetup();

    await serverConnection.sendAddOverlay(src);
    await serverConnection.analysisComplete.first;
    var fixes = await serverConnection.sendGetFixes(offset);
    await serverConnection.sendRemoveOverlay();
    return fixes;
  }

  Future<EditFormatResult> _formatImpl(String src, int offset) async {
    await serverConnection._ensureSetup();
    await serverConnection.sendAddOverlay(src);
    await serverConnection.analysisComplete.first;
    var formatResult = await serverConnection.sendFormat(offset);
    await serverConnection.sendRemoveOverlay();
    return formatResult;
  }

  /// Warm up the analysis server to be ready for use.
  Future warmup([bool useHtml = false]) =>
      _completeImpl(
          {mainPath : useHtml ? _WARMUP_SRC_HTML : _WARMUP_SRC},
          mainPath, 10);
}

/**
 * Instances of the class [_Server] manage a connection to a server process, and
 * facilitate communication to and from the server.
 */
class _Server {
  final String _sdkPath;

  /// Control flags to handle the server state machine
  bool isSetup = false;
  bool isSettingUp = false;

  // TODO(lukechurch): Replace this with a notice board + dispatcher pattern
  /// Streams used to handle syncing data with the server
  Stream<bool> analysisComplete;
  StreamController<bool> _onServerStatus;

  Stream<Map> completionResults;
  StreamController<Map> _onCompletionResults;

  _Server(this._sdkPath) {
    _onServerStatus = new StreamController<bool>(sync: true);
    analysisComplete = _onServerStatus.stream.asBroadcastStream();

    _onCompletionResults = new StreamController(sync: true);
    completionResults = _onCompletionResults.stream.asBroadcastStream();

  }

  /// Ensure that the server is ready for use.
  Future _ensureSetup() async {
    _logger.fine("ensureSetup: SETUP $isSetup IS_SETTING_UP $isSettingUp");
    if (!isSetup && !isSettingUp) {
      return _setup();
    }
    return new Future.value();
  }

  Future _setup() async {
    _logger.fine("Setup starting");
    isSettingUp = true;

    _logger.fine("Server about to start");

    await start();
    _logger.fine("Setver started");

    listenToOutput(dispatchNotification);
    sendServerSetSubscriptions([ServerService.STATUS]);

    _logger.fine("Server Set Subscriptions completed");

    await sendAddOverlay(
        "${sourceDirectory.path}${io.Platform.pathSeparator}main.dart",
        _WARMUP_SRC);
    sendAnalysisSetAnalysisRoots([sourceDirectory.path], []);
    isSettingUp = false;
    isSetup = true;

    _logger.fine("Setup done");
    return analysisComplete.first;
  }

  Future loadSources(Map<String, String> sources) async {
    for (String path in sources.keys) {
      String source = sources[path];
      await sendAddOverlay(path, source);
    }
    await sendPrioritySetSources(sources.keys.toList());
  }

  Future unloadSources(List<String> paths) async {
    for (String path in paths) {
      await sendRemoveOverlay(path);
    }
  }

  /**
   * Server process object, or null if server hasn't been started yet.
   */
  io.Process _process;

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
   * Stopwatch that we use to generate timing information for debug output.
   */
  Stopwatch _time = new Stopwatch();

  /**
   * Future that completes when the server process exits.
   */
  Future<int> get exitCode => _process.exitCode;

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
    _logStdio('PROCESS FORCIBLY TERMINATED');
    _process.kill();
    Future<int> exitCode = _process.exitCode;
    _process = null;
    return exitCode;
  }

  /**
   * Start listening to output from the server, and deliver notifications to
   * [notificationProcessor].
   */
  void listenToOutput(NotificationProcessor notificationProcessor) {
    _process.stdout.transform(
        (new Utf8Codec()).decoder).transform(new LineSplitter()).listen((String line) {
      String trimmedLine = line.trim();

      _logStdio('RECV: $trimmedLine');
      var message;
      try {
        message = JSON.decoder.convert(trimmedLine);
      } catch (exception) {
        _logger.severe("Bad data from server");
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
          kill();
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
      _logStdio('ERR:  ${line.trim()}');
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
    _logger.fine("Server.send $method");

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
    _logStdio('SEND: $line');
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
    if (_process != null) throw new Exception('Process already started');

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

    arguments.add(_SERVER_PATH);

    arguments.add('--sdk');
    arguments.add(_sdkPath);

    _logger.fine("Binary: $dartBinary");
    _logger.fine("Arguments: $arguments");

    return io.Process.start(dartBinary, arguments).then((io.Process process) {
      _logger.fine("io.Process.then returned");

      _process = process;
      process.exitCode.then((int code) {
        _logStdio('TERMINATED WITH EXIT CODE $code');

      });
    });
  }

  Future sendServerSetSubscriptions(List<ServerService> subscriptions) {
    var params = new ServerSetSubscriptionsParams(subscriptions).toJson();
    return send("server.setSubscriptions", params);
  }

  Future sendPrioritySetSources(List<String> paths) {
    var params = new AnalysisSetPriorityFilesParams(paths).toJson();
    return send("analysis.setPriorityFiles", params);
  }

  Future<ServerGetVersionResult> sendServerGetVersion() {
    return send("server.getVersion", null).then((result) {
      ResponseDecoder decoder = new ResponseDecoder(null);
      return new ServerGetVersionResult.fromJson(decoder, 'result', result);
    });
  }

  Future<CompletionGetSuggestionsResult> sendCompletionGetSuggestions(
      String path, int offset) {

    var params = new CompletionGetSuggestionsParams(path, offset).toJson();
    return send("completion.getSuggestions", params).then((result) {
      ResponseDecoder decoder = new ResponseDecoder(null);
      return new CompletionGetSuggestionsResult.fromJson(decoder, 'result', result);
    });
  }

  Future<EditGetFixesResult> sendGetFixes(String path, int offset) {
    var params = new EditGetFixesParams(path, offset).toJson();
    return send("edit.getFixes", params).then((result) {
      ResponseDecoder decoder = new ResponseDecoder(null);
      return new EditGetFixesResult.fromJson(decoder, 'result', result);
    });
  }

  Future<EditFormatResult> sendFormat(int selectionOffset,
    [int selectionLength = 0]) {

    String file = psuedoFilePath;
    var params = new EditFormatParams(
        file, selectionOffset, selectionLength).toJson();

    return send("edit.format", params).then((result) {
      ResponseDecoder decoder = new ResponseDecoder(null);
      return new EditFormatResult.fromJson(decoder, 'result', result);
    });
  }

  Future<AnalysisUpdateContentResult> sendAddOverlay(String path, String contents) {
    var overlay = new AddContentOverlay(contents);
    var params = new AnalysisUpdateContentParams({path: overlay}).toJson();
    _logger.fine("About to send analysis.updateContent");
    return send("analysis.updateContent", params).then((result) {
      _logger.fine("analysis.updateContent -> then");

      ResponseDecoder decoder = new ResponseDecoder(null);
      return new AnalysisUpdateContentResult.fromJson(decoder, 'result', result);
    });
  }

  Future<AnalysisUpdateContentResult> sendRemoveOverlay(String path) {
    var overlay = new RemoveContentOverlay();
    var params = new AnalysisUpdateContentParams({path: overlay}).toJson();
    _logger.fine("About to send analysis.updateContent - remove overlay");
    return send("analysis.updateContent", params).then((result) {
      _logger.fine("analysis.updateContent -> then");

      ResponseDecoder decoder = new ResponseDecoder(null);
      return new AnalysisUpdateContentResult.fromJson(decoder, 'result', result);
    });
  }

  Future sendServerShutdown() {
    return send("server.shutdown", null).then((result) {
      return null;
    });
  }

  Future sendAnalysisSetAnalysisRoots(List<String> included, List<String> excluded,
      {Map<String, String> packageRoots}) {
    var params = new AnalysisSetAnalysisRootsParams(
        included, excluded, packageRoots: packageRoots).toJson();
    return send("analysis.setAnalysisRoots", params);
  }

  Future dispatchNotification(String event, params) async {
    if (event == "server.error") {
      // Something has gone wrong with the analysis server. This request is going
      // to fail, but we need to restart the server to be able to process
      // another request
      isSetup = false;
      isSettingUp = false;

      await kill();
      _onCompletionResults.addError(null);
      _logger.severe("Analysis server has crashed. $event");
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

  /**
   * Record a message that was exchanged with the server, and print it out if
   * [dumpServerMessages] is true.
   */
  void _logStdio(String line) {
    if (dumpServerMessages) print(line);
  }
}
