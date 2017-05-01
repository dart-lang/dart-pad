// Copyright (c) 2017, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This is a generated file.

/// A library to access the analysis server API.
library analysis_server_lib;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// @optional
const String optional = 'optional';

/// @experimental
const String experimental = 'experimental';

final Logger _logger = new Logger('analysis_server_lib');

const String generatedProtocolVersion = '1.18.1';

typedef void MethodSend(String methodName);

class Server {
  static Future<Server> createFromDefaults(
      {onRead(String), onWrite(String)}) async {
    Completer<int> processCompleter = new Completer();
    String sdk = path.dirname(path.dirname(Platform.resolvedExecutable));
    String snapshot = '${sdk}/bin/snapshots/analysis_server.dart.snapshot';

    Process process = await Process
        .start(Platform.resolvedExecutable, [snapshot, '--sdk', sdk]);
    process.exitCode.then((code) => processCompleter.complete(code));

    Stream<String> inStream = process.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .map((String message) {
      if (onRead != null) onRead(message);
      return message;
    });

    Server server = new Server(inStream, (String message) {
      if (onWrite != null) onWrite(message);
      process.stdin.writeln(message);
    }, processCompleter, process.kill);

    return server;
  }

  final Completer<int> processCompleter;
  final Function _processKillHandler;

  StreamSubscription _streamSub;
  Function _writeMessage;
  int _id = 0;
  Map<String, Completer> _completers = {};
  Map<String, String> _methodNames = {};
  JsonCodec _jsonEncoder = new JsonCodec(toEncodable: _toEncodable);
  Map<String, Domain> _domains = {};
  StreamController<String> _onSend = new StreamController.broadcast();
  StreamController<String> _onReceive = new StreamController.broadcast();
  MethodSend _willSend;

  ServerDomain _server;
  AnalysisDomain _analysis;
  CompletionDomain _completion;
  SearchDomain _search;
  EditDomain _edit;
  ExecutionDomain _execution;
  DiagnosticDomain _diagnostic;

  Server(Stream<String> inStream, void writeMessage(String message),
      this.processCompleter,
      [this._processKillHandler]) {
    configure(inStream, writeMessage);

    _server = new ServerDomain(this);
    _analysis = new AnalysisDomain(this);
    _completion = new CompletionDomain(this);
    _search = new SearchDomain(this);
    _edit = new EditDomain(this);
    _execution = new ExecutionDomain(this);
    _diagnostic = new DiagnosticDomain(this);
  }

  ServerDomain get server => _server;
  AnalysisDomain get analysis => _analysis;
  CompletionDomain get completion => _completion;
  SearchDomain get search => _search;
  EditDomain get edit => _edit;
  ExecutionDomain get execution => _execution;
  DiagnosticDomain get diagnostic => _diagnostic;

  Stream<String> get onSend => _onSend.stream;
  Stream<String> get onReceive => _onReceive.stream;

  set willSend(MethodSend fn) {
    _willSend = fn;
  }

  void configure(Stream<String> inStream, void writeMessage(String message)) {
    _streamSub = inStream.listen(_processMessage);
    _writeMessage = writeMessage;
  }

  void dispose() {
    if (_streamSub != null) _streamSub.cancel();
    //_completers.values.forEach((c) => c.completeError('disposed'));
    _completers.clear();

    if (_processKillHandler != null) {
      _processKillHandler();
    }
  }

  void _processMessage(String message) {
    _onReceive.add(message);

    if (!message.startsWith('{')) {
      _logger.warning('unknown message: ${message}');
      return;
    }

    try {
      var json = JSON.decode(message);

      if (json['id'] == null) {
        // Handle a notification.
        String event = json['event'];
        if (event == null) {
          _logger.severe('invalid message: ${message}');
        } else {
          String prefix = event.substring(0, event.indexOf('.'));
          if (_domains[prefix] == null) {
            _logger.severe('no domain for notification: ${message}');
          } else {
            _domains[prefix]._handleEvent(event, json['params']);
          }
        }
      } else {
        Completer completer = _completers.remove(json['id']);
        String methodName = _methodNames.remove(json['id']);

        if (completer == null) {
          _logger.severe('unmatched request response: ${message}');
        } else if (json['error'] != null) {
          completer
              .completeError(RequestError.parse(methodName, json['error']));
        } else {
          completer.complete(json['result']);
        }
      }
    } catch (e) {
      _logger.severe('unable to decode message: ${message}, ${e}');
    }
  }

  Future _call(String method, [Map args]) {
    String id = '${++_id}';
    _completers[id] = new Completer();
    _methodNames[id] = method;
    Map m = {'id': id, 'method': method};
    if (args != null) m['params'] = args;
    String message = _jsonEncoder.encode(m);
    if (_willSend != null) _willSend(method);
    _onSend.add(message);
    _writeMessage(message);
    return _completers[id].future;
  }

  static dynamic _toEncodable(obj) => obj is Jsonable ? obj.toMap() : obj;
}

abstract class Domain {
  final Server server;
  final String name;

  Map<String, StreamController> _controllers = {};
  Map<String, Stream> _streams = {};

  Domain(this.server, this.name) {
    server._domains[name] = this;
  }

  Future _call(String method, [Map args]) => server._call(method, args);

  Stream<dynamic> _listen(String name, Function cvt) {
    if (_streams[name] == null) {
      _controllers[name] = new StreamController.broadcast();
      _streams[name] = _controllers[name].stream.map(cvt);
    }

    return _streams[name];
  }

  void _handleEvent(String name, dynamic event) {
    if (_controllers[name] != null) {
      _controllers[name].add(event);
    }
  }

  String toString() => 'Domain ${name}';
}

abstract class Jsonable {
  Map toMap();
}

abstract class RefactoringOptions implements Jsonable {}

class RequestError {
  static RequestError parse(String method, Map m) {
    if (m == null) return null;
    return new RequestError(method, m['code'], m['message'],
        stackTrace: m['stackTrace']);
  }

  final String method;
  final String code;
  final String message;
  @optional
  final String stackTrace;

  RequestError(this.method, this.code, this.message, {this.stackTrace});

  String toString() =>
      '[Analyzer RequestError method: ${method}, code: ${code}, message: ${message}]';
}

Map _stripNullValues(Map m) {
  Map copy = {};

  for (var key in m.keys) {
    var value = m[key];
    if (value != null) copy[key] = value;
  }

  return copy;
}

// server domain

class ServerDomain extends Domain {
  ServerDomain(Server server) : super(server, 'server');

  Stream<ServerConnected> get onConnected {
    return _listen('server.connected', ServerConnected.parse)
        as Stream<ServerConnected>;
  }

  Stream<ServerError> get onError {
    return _listen('server.error', ServerError.parse) as Stream<ServerError>;
  }

  Stream<ServerStatus> get onStatus {
    return _listen('server.status', ServerStatus.parse) as Stream<ServerStatus>;
  }

  Future<VersionResult> getVersion() =>
      _call('server.getVersion').then(VersionResult.parse);

  Future shutdown() => _call('server.shutdown');

  Future setSubscriptions(List<String> subscriptions) =>
      _call('server.setSubscriptions', {'subscriptions': subscriptions});
}

class ServerConnected {
  static ServerConnected parse(Map m) =>
      new ServerConnected(m['version'], m['pid'], sessionId: m['sessionId']);

  final String version;
  final int pid;
  @optional
  final String sessionId;

  ServerConnected(this.version, this.pid, {this.sessionId});
}

class ServerError {
  static ServerError parse(Map m) =>
      new ServerError(m['isFatal'], m['message'], m['stackTrace']);

  final bool isFatal;
  final String message;
  final String stackTrace;

  ServerError(this.isFatal, this.message, this.stackTrace);
}

class ServerStatus {
  static ServerStatus parse(Map m) => new ServerStatus(
      analysis: AnalysisStatus.parse(m['analysis']),
      pub: PubStatus.parse(m['pub']));

  @optional
  final AnalysisStatus analysis;
  @optional
  final PubStatus pub;

  ServerStatus({this.analysis, this.pub});
}

class VersionResult {
  static VersionResult parse(Map m) => new VersionResult(m['version']);

  final String version;

  VersionResult(this.version);
}

// analysis domain

class AnalysisDomain extends Domain {
  AnalysisDomain(Server server) : super(server, 'analysis');

  Stream<AnalysisAnalyzedFiles> get onAnalyzedFiles {
    return _listen('analysis.analyzedFiles', AnalysisAnalyzedFiles.parse)
        as Stream<AnalysisAnalyzedFiles>;
  }

  Stream<AnalysisErrors> get onErrors {
    return _listen('analysis.errors', AnalysisErrors.parse)
        as Stream<AnalysisErrors>;
  }

  Stream<AnalysisFlushResults> get onFlushResults {
    return _listen('analysis.flushResults', AnalysisFlushResults.parse)
        as Stream<AnalysisFlushResults>;
  }

  Stream<AnalysisFolding> get onFolding {
    return _listen('analysis.folding', AnalysisFolding.parse)
        as Stream<AnalysisFolding>;
  }

  Stream<AnalysisHighlights> get onHighlights {
    return _listen('analysis.highlights', AnalysisHighlights.parse)
        as Stream<AnalysisHighlights>;
  }

  Stream<AnalysisImplemented> get onImplemented {
    return _listen('analysis.implemented', AnalysisImplemented.parse)
        as Stream<AnalysisImplemented>;
  }

  Stream<AnalysisInvalidate> get onInvalidate {
    return _listen('analysis.invalidate', AnalysisInvalidate.parse)
        as Stream<AnalysisInvalidate>;
  }

  Stream<AnalysisNavigation> get onNavigation {
    return _listen('analysis.navigation', AnalysisNavigation.parse)
        as Stream<AnalysisNavigation>;
  }

  Stream<AnalysisOccurrences> get onOccurrences {
    return _listen('analysis.occurrences', AnalysisOccurrences.parse)
        as Stream<AnalysisOccurrences>;
  }

  Stream<AnalysisOutline> get onOutline {
    return _listen('analysis.outline', AnalysisOutline.parse)
        as Stream<AnalysisOutline>;
  }

  Stream<AnalysisOverrides> get onOverrides {
    return _listen('analysis.overrides', AnalysisOverrides.parse)
        as Stream<AnalysisOverrides>;
  }

  Future<ErrorsResult> getErrors(String file) {
    Map m = {'file': file};
    return _call('analysis.getErrors', m).then(ErrorsResult.parse);
  }

  Future<HoverResult> getHover(String file, int offset) {
    Map m = {'file': file, 'offset': offset};
    return _call('analysis.getHover', m).then(HoverResult.parse);
  }

  Future<ReachableSourcesResult> getReachableSources(String file) {
    Map m = {'file': file};
    return _call('analysis.getReachableSources', m)
        .then(ReachableSourcesResult.parse);
  }

  Future<LibraryDependenciesResult> getLibraryDependencies() =>
      _call('analysis.getLibraryDependencies')
          .then(LibraryDependenciesResult.parse);

  Future<NavigationResult> getNavigation(String file, int offset, int length) {
    Map m = {'file': file, 'offset': offset, 'length': length};
    return _call('analysis.getNavigation', m).then(NavigationResult.parse);
  }

  Future reanalyze({List<String> roots}) {
    Map m = {};
    if (roots != null) m['roots'] = roots;
    return _call('analysis.reanalyze', m);
  }

  Future setAnalysisRoots(List<String> included, List<String> excluded,
      {Map<String, String> packageRoots}) {
    Map m = {'included': included, 'excluded': excluded};
    if (packageRoots != null) m['packageRoots'] = packageRoots;
    return _call('analysis.setAnalysisRoots', m);
  }

  Future setGeneralSubscriptions(List<String> subscriptions) => _call(
      'analysis.setGeneralSubscriptions', {'subscriptions': subscriptions});

  Future setPriorityFiles(List<String> files) =>
      _call('analysis.setPriorityFiles', {'files': files});

  Future setSubscriptions(Map<String, List<String>> subscriptions) =>
      _call('analysis.setSubscriptions', {'subscriptions': subscriptions});

  Future updateContent(Map<String, ContentOverlayType> files) =>
      _call('analysis.updateContent', {'files': files});

  Future updateOptions(AnalysisOptions options) =>
      _call('analysis.updateOptions', {'options': options});
}

class AnalysisAnalyzedFiles {
  static AnalysisAnalyzedFiles parse(Map m) => new AnalysisAnalyzedFiles(
      m['directories'] == null ? null : new List.from(m['directories']));

  final List<String> directories;

  AnalysisAnalyzedFiles(this.directories);
}

class AnalysisErrors {
  static AnalysisErrors parse(Map m) => new AnalysisErrors(
      m['file'],
      m['errors'] == null
          ? null
          : new List.from(m['errors'].map((obj) => AnalysisError.parse(obj))));

  final String file;
  final List<AnalysisError> errors;

  AnalysisErrors(this.file, this.errors);
}

class AnalysisFlushResults {
  static AnalysisFlushResults parse(Map m) => new AnalysisFlushResults(
      m['files'] == null ? null : new List.from(m['files']));

  final List<String> files;

  AnalysisFlushResults(this.files);
}

class AnalysisFolding {
  static AnalysisFolding parse(Map m) => new AnalysisFolding(
      m['file'],
      m['regions'] == null
          ? null
          : new List.from(m['regions'].map((obj) => FoldingRegion.parse(obj))));

  final String file;
  final List<FoldingRegion> regions;

  AnalysisFolding(this.file, this.regions);
}

class AnalysisHighlights {
  static AnalysisHighlights parse(Map m) => new AnalysisHighlights(
      m['file'],
      m['regions'] == null
          ? null
          : new List.from(
              m['regions'].map((obj) => HighlightRegion.parse(obj))));

  final String file;
  final List<HighlightRegion> regions;

  AnalysisHighlights(this.file, this.regions);
}

class AnalysisImplemented {
  static AnalysisImplemented parse(Map m) => new AnalysisImplemented(
      m['file'],
      m['classes'] == null
          ? null
          : new List.from(
              m['classes'].map((obj) => ImplementedClass.parse(obj))),
      m['members'] == null
          ? null
          : new List.from(
              m['members'].map((obj) => ImplementedMember.parse(obj))));

  final String file;
  final List<ImplementedClass> classes;
  final List<ImplementedMember> members;

  AnalysisImplemented(this.file, this.classes, this.members);
}

class AnalysisInvalidate {
  static AnalysisInvalidate parse(Map m) =>
      new AnalysisInvalidate(m['file'], m['offset'], m['length'], m['delta']);

  final String file;
  final int offset;
  final int length;
  final int delta;

  AnalysisInvalidate(this.file, this.offset, this.length, this.delta);
}

class AnalysisNavigation {
  static AnalysisNavigation parse(Map m) => new AnalysisNavigation(
      m['file'],
      m['regions'] == null
          ? null
          : new List.from(
              m['regions'].map((obj) => NavigationRegion.parse(obj))),
      m['targets'] == null
          ? null
          : new List.from(
              m['targets'].map((obj) => NavigationTarget.parse(obj))),
      m['files'] == null ? null : new List.from(m['files']));

  final String file;
  final List<NavigationRegion> regions;
  final List<NavigationTarget> targets;
  final List<String> files;

  AnalysisNavigation(this.file, this.regions, this.targets, this.files);
}

class AnalysisOccurrences {
  static AnalysisOccurrences parse(Map m) => new AnalysisOccurrences(
      m['file'],
      m['occurrences'] == null
          ? null
          : new List.from(
              m['occurrences'].map((obj) => Occurrences.parse(obj))));

  final String file;
  final List<Occurrences> occurrences;

  AnalysisOccurrences(this.file, this.occurrences);
}

class AnalysisOutline {
  static AnalysisOutline parse(Map m) =>
      new AnalysisOutline(m['file'], m['kind'], Outline.parse(m['outline']),
          libraryName: m['libraryName']);

  final String file;
  final String kind;
  final Outline outline;
  @optional
  final String libraryName;

  AnalysisOutline(this.file, this.kind, this.outline, {this.libraryName});
}

class AnalysisOverrides {
  static AnalysisOverrides parse(Map m) => new AnalysisOverrides(
      m['file'],
      m['overrides'] == null
          ? null
          : new List.from(m['overrides'].map((obj) => Override.parse(obj))));

  final String file;
  final List<Override> overrides;

  AnalysisOverrides(this.file, this.overrides);
}

class ErrorsResult {
  static ErrorsResult parse(Map m) => new ErrorsResult(m['errors'] == null
      ? null
      : new List.from(m['errors'].map((obj) => AnalysisError.parse(obj))));

  final List<AnalysisError> errors;

  ErrorsResult(this.errors);
}

class HoverResult {
  static HoverResult parse(Map m) => new HoverResult(m['hovers'] == null
      ? null
      : new List.from(m['hovers'].map((obj) => HoverInformation.parse(obj))));

  final List<HoverInformation> hovers;

  HoverResult(this.hovers);
}

class ReachableSourcesResult {
  static ReachableSourcesResult parse(Map m) =>
      new ReachableSourcesResult(new Map.from(m['sources']));

  final Map<String, List<String>> sources;

  ReachableSourcesResult(this.sources);
}

class LibraryDependenciesResult {
  static LibraryDependenciesResult parse(Map m) =>
      new LibraryDependenciesResult(
          m['libraries'] == null ? null : new List.from(m['libraries']),
          new Map.from(m['packageMap']));

  final List<String> libraries;
  final Map<String, Map<String, List<String>>> packageMap;

  LibraryDependenciesResult(this.libraries, this.packageMap);
}

class NavigationResult {
  static NavigationResult parse(Map m) => new NavigationResult(
      m['files'] == null ? null : new List.from(m['files']),
      m['targets'] == null
          ? null
          : new List.from(
              m['targets'].map((obj) => NavigationTarget.parse(obj))),
      m['regions'] == null
          ? null
          : new List.from(
              m['regions'].map((obj) => NavigationRegion.parse(obj))));

  final List<String> files;
  final List<NavigationTarget> targets;
  final List<NavigationRegion> regions;

  NavigationResult(this.files, this.targets, this.regions);
}

// completion domain

class CompletionDomain extends Domain {
  CompletionDomain(Server server) : super(server, 'completion');

  Stream<CompletionResults> get onResults {
    return _listen('completion.results', CompletionResults.parse)
        as Stream<CompletionResults>;
  }

  Future<SuggestionsResult> getSuggestions(String file, int offset) {
    Map m = {'file': file, 'offset': offset};
    return _call('completion.getSuggestions', m).then(SuggestionsResult.parse);
  }
}

class CompletionResults {
  static CompletionResults parse(Map m) => new CompletionResults(
      m['id'],
      m['replacementOffset'],
      m['replacementLength'],
      m['results'] == null
          ? null
          : new List.from(
              m['results'].map((obj) => CompletionSuggestion.parse(obj))),
      m['isLast']);

  final String id;
  final int replacementOffset;
  final int replacementLength;
  final List<CompletionSuggestion> results;
  final bool isLast;

  CompletionResults(this.id, this.replacementOffset, this.replacementLength,
      this.results, this.isLast);
}

class SuggestionsResult {
  static SuggestionsResult parse(Map m) => new SuggestionsResult(m['id']);

  final String id;

  SuggestionsResult(this.id);
}

// search domain

class SearchDomain extends Domain {
  SearchDomain(Server server) : super(server, 'search');

  Stream<SearchResults> get onResults {
    return _listen('search.results', SearchResults.parse)
        as Stream<SearchResults>;
  }

  Future<FindElementReferencesResult> findElementReferences(
      String file, int offset, bool includePotential) {
    Map m = {
      'file': file,
      'offset': offset,
      'includePotential': includePotential
    };
    return _call('search.findElementReferences', m)
        .then(FindElementReferencesResult.parse);
  }

  Future<FindMemberDeclarationsResult> findMemberDeclarations(String name) {
    Map m = {'name': name};
    return _call('search.findMemberDeclarations', m)
        .then(FindMemberDeclarationsResult.parse);
  }

  Future<FindMemberReferencesResult> findMemberReferences(String name) {
    Map m = {'name': name};
    return _call('search.findMemberReferences', m)
        .then(FindMemberReferencesResult.parse);
  }

  Future<FindTopLevelDeclarationsResult> findTopLevelDeclarations(
      String pattern) {
    Map m = {'pattern': pattern};
    return _call('search.findTopLevelDeclarations', m)
        .then(FindTopLevelDeclarationsResult.parse);
  }

  Future<TypeHierarchyResult> getTypeHierarchy(String file, int offset,
      {bool superOnly}) {
    Map m = {'file': file, 'offset': offset};
    if (superOnly != null) m['superOnly'] = superOnly;
    return _call('search.getTypeHierarchy', m).then(TypeHierarchyResult.parse);
  }
}

class SearchResults {
  static SearchResults parse(Map m) => new SearchResults(
      m['id'],
      m['results'] == null
          ? null
          : new List.from(m['results'].map((obj) => SearchResult.parse(obj))),
      m['isLast']);

  final String id;
  final List<SearchResult> results;
  final bool isLast;

  SearchResults(this.id, this.results, this.isLast);
}

class FindElementReferencesResult {
  static FindElementReferencesResult parse(Map m) =>
      new FindElementReferencesResult(
          id: m['id'], element: Element.parse(m['element']));

  @optional
  final String id;
  @optional
  final Element element;

  FindElementReferencesResult({this.id, this.element});
}

class FindMemberDeclarationsResult {
  static FindMemberDeclarationsResult parse(Map m) =>
      new FindMemberDeclarationsResult(m['id']);

  final String id;

  FindMemberDeclarationsResult(this.id);
}

class FindMemberReferencesResult {
  static FindMemberReferencesResult parse(Map m) =>
      new FindMemberReferencesResult(m['id']);

  final String id;

  FindMemberReferencesResult(this.id);
}

class FindTopLevelDeclarationsResult {
  static FindTopLevelDeclarationsResult parse(Map m) =>
      new FindTopLevelDeclarationsResult(m['id']);

  final String id;

  FindTopLevelDeclarationsResult(this.id);
}

class TypeHierarchyResult {
  static TypeHierarchyResult parse(Map m) => new TypeHierarchyResult(
      hierarchyItems: m['hierarchyItems'] == null
          ? null
          : new List.from(
              m['hierarchyItems'].map((obj) => TypeHierarchyItem.parse(obj))));

  @optional
  final List<TypeHierarchyItem> hierarchyItems;

  TypeHierarchyResult({this.hierarchyItems});
}

// edit domain

class EditDomain extends Domain {
  EditDomain(Server server) : super(server, 'edit');

  Future<FormatResult> format(
      String file, int selectionOffset, int selectionLength,
      {int lineLength}) {
    Map m = {
      'file': file,
      'selectionOffset': selectionOffset,
      'selectionLength': selectionLength
    };
    if (lineLength != null) m['lineLength'] = lineLength;
    return _call('edit.format', m).then(FormatResult.parse);
  }

  Future<AssistsResult> getAssists(String file, int offset, int length) {
    Map m = {'file': file, 'offset': offset, 'length': length};
    return _call('edit.getAssists', m).then(AssistsResult.parse);
  }

  Future<AvailableRefactoringsResult> getAvailableRefactorings(
      String file, int offset, int length) {
    Map m = {'file': file, 'offset': offset, 'length': length};
    return _call('edit.getAvailableRefactorings', m)
        .then(AvailableRefactoringsResult.parse);
  }

  Future<FixesResult> getFixes(String file, int offset) {
    Map m = {'file': file, 'offset': offset};
    return _call('edit.getFixes', m).then(FixesResult.parse);
  }

  Future<RefactoringResult> getRefactoring(
      String kind, String file, int offset, int length, bool validateOnly,
      {RefactoringOptions options}) {
    Map m = {
      'kind': kind,
      'file': file,
      'offset': offset,
      'length': length,
      'validateOnly': validateOnly
    };
    if (options != null) m['options'] = options;
    return _call('edit.getRefactoring', m).then(RefactoringResult.parse);
  }

  @experimental
  Future<StatementCompletionResult> getStatementCompletion(
      String file, int offset) {
    Map m = {'file': file, 'offset': offset};
    return _call('edit.getStatementCompletion', m)
        .then(StatementCompletionResult.parse);
  }

  Future<SortMembersResult> sortMembers(String file) {
    Map m = {'file': file};
    return _call('edit.sortMembers', m).then(SortMembersResult.parse);
  }

  Future<OrganizeDirectivesResult> organizeDirectives(String file) {
    Map m = {'file': file};
    return _call('edit.organizeDirectives', m)
        .then(OrganizeDirectivesResult.parse);
  }
}

class FormatResult {
  static FormatResult parse(Map m) => new FormatResult(
      m['edits'] == null
          ? null
          : new List.from(m['edits'].map((obj) => SourceEdit.parse(obj))),
      m['selectionOffset'],
      m['selectionLength']);

  final List<SourceEdit> edits;
  final int selectionOffset;
  final int selectionLength;

  FormatResult(this.edits, this.selectionOffset, this.selectionLength);
}

class AssistsResult {
  static AssistsResult parse(Map m) => new AssistsResult(m['assists'] == null
      ? null
      : new List.from(m['assists'].map((obj) => SourceChange.parse(obj))));

  final List<SourceChange> assists;

  AssistsResult(this.assists);
}

class AvailableRefactoringsResult {
  static AvailableRefactoringsResult parse(Map m) =>
      new AvailableRefactoringsResult(
          m['kinds'] == null ? null : new List.from(m['kinds']));

  final List<String> kinds;

  AvailableRefactoringsResult(this.kinds);
}

class FixesResult {
  static FixesResult parse(Map m) => new FixesResult(m['fixes'] == null
      ? null
      : new List.from(m['fixes'].map((obj) => AnalysisErrorFixes.parse(obj))));

  final List<AnalysisErrorFixes> fixes;

  FixesResult(this.fixes);
}

class RefactoringResult {
  static RefactoringResult parse(Map m) => new RefactoringResult(
      m['initialProblems'] == null
          ? null
          : new List.from(
              m['initialProblems'].map((obj) => RefactoringProblem.parse(obj))),
      m['optionsProblems'] == null
          ? null
          : new List.from(
              m['optionsProblems'].map((obj) => RefactoringProblem.parse(obj))),
      m['finalProblems'] == null
          ? null
          : new List.from(
              m['finalProblems'].map((obj) => RefactoringProblem.parse(obj))),
      feedback: RefactoringFeedback.parse(m['feedback']),
      change: SourceChange.parse(m['change']),
      potentialEdits: m['potentialEdits'] == null
          ? null
          : new List.from(m['potentialEdits']));

  final List<RefactoringProblem> initialProblems;
  final List<RefactoringProblem> optionsProblems;
  final List<RefactoringProblem> finalProblems;
  @optional
  final RefactoringFeedback feedback;
  @optional
  final SourceChange change;
  @optional
  final List<String> potentialEdits;

  RefactoringResult(
      this.initialProblems, this.optionsProblems, this.finalProblems,
      {this.feedback, this.change, this.potentialEdits});
}

class StatementCompletionResult {
  static StatementCompletionResult parse(Map m) =>
      new StatementCompletionResult(
          SourceChange.parse(m['change']), m['whitespaceOnly']);

  final SourceChange change;
  final bool whitespaceOnly;

  StatementCompletionResult(this.change, this.whitespaceOnly);
}

class SortMembersResult {
  static SortMembersResult parse(Map m) =>
      new SortMembersResult(SourceFileEdit.parse(m['edit']));

  final SourceFileEdit edit;

  SortMembersResult(this.edit);
}

class OrganizeDirectivesResult {
  static OrganizeDirectivesResult parse(Map m) =>
      new OrganizeDirectivesResult(SourceFileEdit.parse(m['edit']));

  final SourceFileEdit edit;

  OrganizeDirectivesResult(this.edit);
}

// execution domain

class ExecutionDomain extends Domain {
  ExecutionDomain(Server server) : super(server, 'execution');

  Stream<ExecutionLaunchData> get onLaunchData {
    return _listen('execution.launchData', ExecutionLaunchData.parse)
        as Stream<ExecutionLaunchData>;
  }

  Future<CreateContextResult> createContext(String contextRoot) {
    Map m = {'contextRoot': contextRoot};
    return _call('execution.createContext', m).then(CreateContextResult.parse);
  }

  Future deleteContext(String id) =>
      _call('execution.deleteContext', {'id': id});

  Future<MapUriResult> mapUri(String id, {String file, String uri}) {
    Map m = {'id': id};
    if (file != null) m['file'] = file;
    if (uri != null) m['uri'] = uri;
    return _call('execution.mapUri', m).then(MapUriResult.parse);
  }

  Future setSubscriptions(List<String> subscriptions) =>
      _call('execution.setSubscriptions', {'subscriptions': subscriptions});
}

class ExecutionLaunchData {
  static ExecutionLaunchData parse(Map m) => new ExecutionLaunchData(m['file'],
      kind: m['kind'],
      referencedFiles: m['referencedFiles'] == null
          ? null
          : new List.from(m['referencedFiles']));

  final String file;
  @optional
  final String kind;
  @optional
  final List<String> referencedFiles;

  ExecutionLaunchData(this.file, {this.kind, this.referencedFiles});
}

class CreateContextResult {
  static CreateContextResult parse(Map m) => new CreateContextResult(m['id']);

  final String id;

  CreateContextResult(this.id);
}

class MapUriResult {
  static MapUriResult parse(Map m) =>
      new MapUriResult(file: m['file'], uri: m['uri']);

  @optional
  final String file;
  @optional
  final String uri;

  MapUriResult({this.file, this.uri});
}

// diagnostic domain

class DiagnosticDomain extends Domain {
  DiagnosticDomain(Server server) : super(server, 'diagnostic');

  Future<DiagnosticsResult> getDiagnostics() =>
      _call('diagnostic.getDiagnostics').then(DiagnosticsResult.parse);

  Future<ServerPortResult> getServerPort() =>
      _call('diagnostic.getServerPort').then(ServerPortResult.parse);
}

class DiagnosticsResult {
  static DiagnosticsResult parse(Map m) =>
      new DiagnosticsResult(m['contexts'] == null
          ? null
          : new List.from(m['contexts'].map((obj) => ContextData.parse(obj))));

  final List<ContextData> contexts;

  DiagnosticsResult(this.contexts);
}

class ServerPortResult {
  static ServerPortResult parse(Map m) => new ServerPortResult(m['port']);

  final int port;

  ServerPortResult(this.port);
}

// type definitions

class AddContentOverlay extends ContentOverlayType implements Jsonable {
//  static AddContentOverlay parse(Map m) {
//    if (m == null) return null;
//    return new AddContentOverlay(m['type'], m['content']);
//  }

  final String content;

  Map toMap() => _stripNullValues({'type': type, 'content': content});

  AddContentOverlay(this.content) : super('add');
}

class AnalysisError {
  static AnalysisError parse(Map m) {
    if (m == null) return null;
    return new AnalysisError(m['severity'], m['type'],
        Location.parse(m['location']), m['message'], m['code'],
        correction: m['correction'], hasFix: m['hasFix']);
  }

  final String severity;
  final String type;
  final Location location;
  final String message;
  final String code;
  @optional
  final String correction;
  @optional
  final bool hasFix;

  AnalysisError(
      this.severity, this.type, this.location, this.message, this.code,
      {this.correction, this.hasFix});

  operator ==(o) =>
      o is AnalysisError &&
      severity == o.severity &&
      type == o.type &&
      location == o.location &&
      message == o.message &&
      code == o.code &&
      correction == o.correction &&
      hasFix == o.hasFix;

  get hashCode =>
      severity.hashCode ^
      type.hashCode ^
      location.hashCode ^
      message.hashCode ^
      code.hashCode;

  String toString() =>
      '[AnalysisError severity: ${severity}, type: ${type}, location: ${location}, message: ${message}, code: ${code}]';
}

class AnalysisErrorFixes {
  static AnalysisErrorFixes parse(Map m) {
    if (m == null) return null;
    return new AnalysisErrorFixes(
        AnalysisError.parse(m['error']),
        m['fixes'] == null
            ? null
            : new List.from(m['fixes'].map((obj) => SourceChange.parse(obj))));
  }

  final AnalysisError error;
  final List<SourceChange> fixes;

  AnalysisErrorFixes(this.error, this.fixes);
}

class AnalysisOptions implements Jsonable {
  static AnalysisOptions parse(Map m) {
    if (m == null) return null;
    return new AnalysisOptions(
        enableAsync: m['enableAsync'],
        enableDeferredLoading: m['enableDeferredLoading'],
        enableEnums: m['enableEnums'],
        enableNullAwareOperators: m['enableNullAwareOperators'],
        enableSuperMixins: m['enableSuperMixins'],
        generateDart2jsHints: m['generateDart2jsHints'],
        generateHints: m['generateHints'],
        generateLints: m['generateLints']);
  }

  @optional
  final bool enableAsync;
  @optional
  final bool enableDeferredLoading;
  @optional
  final bool enableEnums;
  @optional
  final bool enableNullAwareOperators;
  @optional
  final bool enableSuperMixins;
  @optional
  final bool generateDart2jsHints;
  @optional
  final bool generateHints;
  @optional
  final bool generateLints;

  Map toMap() => _stripNullValues({
        'enableAsync': enableAsync,
        'enableDeferredLoading': enableDeferredLoading,
        'enableEnums': enableEnums,
        'enableNullAwareOperators': enableNullAwareOperators,
        'enableSuperMixins': enableSuperMixins,
        'generateDart2jsHints': generateDart2jsHints,
        'generateHints': generateHints,
        'generateLints': generateLints
      });

  AnalysisOptions(
      {this.enableAsync,
      this.enableDeferredLoading,
      this.enableEnums,
      this.enableNullAwareOperators,
      this.enableSuperMixins,
      this.generateDart2jsHints,
      this.generateHints,
      this.generateLints});
}

class AnalysisStatus {
  static AnalysisStatus parse(Map m) {
    if (m == null) return null;
    return new AnalysisStatus(m['isAnalyzing'],
        analysisTarget: m['analysisTarget']);
  }

  final bool isAnalyzing;
  @optional
  final String analysisTarget;

  AnalysisStatus(this.isAnalyzing, {this.analysisTarget});

  String toString() => '[AnalysisStatus isAnalyzing: ${isAnalyzing}]';
}

class ChangeContentOverlay extends ContentOverlayType implements Jsonable {
//  static ChangeContentOverlay parse(Map m) {
//    if (m == null) return null;
//    return new ChangeContentOverlay(
//        m['type'],
//        m['edits'] == null
//            ? null
//            : new List.from(m['edits'].map((obj) => SourceEdit.parse(obj))));
//  }

//  final String type;
  final List<SourceEdit> edits;

  Map toMap() => _stripNullValues({'type': type, 'edits': edits});

  ChangeContentOverlay(this.edits) : super('change');
}

class CompletionSuggestion {
  static CompletionSuggestion parse(Map m) {
    if (m == null) return null;
    return new CompletionSuggestion(
        m,
        m['kind'],
        m['relevance'],
        m['completion'],
        m['selectionOffset'],
        m['selectionLength'],
        m['isDeprecated'],
        m['isPotential'],
        docSummary: m['docSummary'],
        docComplete: m['docComplete'],
        declaringType: m['declaringType'],
        defaultArgumentListString: m['defaultArgumentListString'],
        defaultArgumentListTextRanges:
            m['defaultArgumentListTextRanges'] == null
                ? null
                : new List.from(m['defaultArgumentListTextRanges']),
        element: Element.parse(m['element']),
        returnType: m['returnType'],
        parameterNames: m['parameterNames'] == null
            ? null
            : new List.from(m['parameterNames']),
        parameterTypes: m['parameterTypes'] == null
            ? null
            : new List.from(m['parameterTypes']),
        requiredParameterCount: m['requiredParameterCount'],
        hasNamedParameters: m['hasNamedParameters'],
        parameterName: m['parameterName'],
        parameterType: m['parameterType'],
        importUri: m['importUri']);
  }

  final Map originalMap;

  final String kind;
  final int relevance;
  final String completion;
  final int selectionOffset;
  final int selectionLength;
  final bool isDeprecated;
  final bool isPotential;
  @optional
  final String docSummary;
  @optional
  final String docComplete;
  @optional
  final String declaringType;
  @optional
  final String defaultArgumentListString;
  @optional
  final List<int> defaultArgumentListTextRanges;
  @optional
  final Element element;
  @optional
  final String returnType;
  @optional
  final List<String> parameterNames;
  @optional
  final List<String> parameterTypes;
  @optional
  final int requiredParameterCount;
  @optional
  final bool hasNamedParameters;
  @optional
  final String parameterName;
  @optional
  final String parameterType;
  @optional
  final String importUri;

  CompletionSuggestion(
      this.originalMap,
      this.kind,
      this.relevance,
      this.completion,
      this.selectionOffset,
      this.selectionLength,
      this.isDeprecated,
      this.isPotential,
      {this.docSummary,
      this.docComplete,
      this.declaringType,
      this.defaultArgumentListString,
      this.defaultArgumentListTextRanges,
      this.element,
      this.returnType,
      this.parameterNames,
      this.parameterTypes,
      this.requiredParameterCount,
      this.hasNamedParameters,
      this.parameterName,
      this.parameterType,
      this.importUri});

  String toString() =>
      '[CompletionSuggestion kind: ${kind}, relevance: ${relevance}, completion: ${completion}, selectionOffset: ${selectionOffset}, selectionLength: ${selectionLength}, isDeprecated: ${isDeprecated}, isPotential: ${isPotential}]';
}

class ContextData {
  static ContextData parse(Map m) {
    if (m == null) return null;
    return new ContextData(
        m['name'],
        m['explicitFileCount'],
        m['implicitFileCount'],
        m['workItemQueueLength'],
        m['cacheEntryExceptions'] == null
            ? null
            : new List.from(m['cacheEntryExceptions']));
  }

  final String name;
  final int explicitFileCount;
  final int implicitFileCount;
  final int workItemQueueLength;
  final List<String> cacheEntryExceptions;

  ContextData(this.name, this.explicitFileCount, this.implicitFileCount,
      this.workItemQueueLength, this.cacheEntryExceptions);
}

class Element {
  static Element parse(Map m) {
    if (m == null) return null;
    return new Element(m['kind'], m['name'], m['flags'],
        location: Location.parse(m['location']),
        parameters: m['parameters'],
        returnType: m['returnType'],
        typeParameters: m['typeParameters']);
  }

  final String kind;
  final String name;
  final int flags;
  @optional
  final Location location;
  @optional
  final String parameters;
  @optional
  final String returnType;
  @optional
  final String typeParameters;

  Element(this.kind, this.name, this.flags,
      {this.location, this.parameters, this.returnType, this.typeParameters});

  String toString() =>
      '[Element kind: ${kind}, name: ${name}, flags: ${flags}]';
}

class ExecutableFile {
  static ExecutableFile parse(Map m) {
    if (m == null) return null;
    return new ExecutableFile(m['file'], m['kind']);
  }

  final String file;
  final String kind;

  ExecutableFile(this.file, this.kind);
}

class FoldingRegion {
  static FoldingRegion parse(Map m) {
    if (m == null) return null;
    return new FoldingRegion(m['kind'], m['offset'], m['length']);
  }

  final String kind;
  final int offset;
  final int length;

  FoldingRegion(this.kind, this.offset, this.length);
}

class HighlightRegion {
  static HighlightRegion parse(Map m) {
    if (m == null) return null;
    return new HighlightRegion(m['type'], m['offset'], m['length']);
  }

  final String type;
  final int offset;
  final int length;

  HighlightRegion(this.type, this.offset, this.length);
}

class HoverInformation {
  static HoverInformation parse(Map m) {
    if (m == null) return null;
    return new HoverInformation(m['offset'], m['length'],
        containingLibraryPath: m['containingLibraryPath'],
        containingLibraryName: m['containingLibraryName'],
        containingClassDescription: m['containingClassDescription'],
        dartdoc: m['dartdoc'],
        elementDescription: m['elementDescription'],
        elementKind: m['elementKind'],
        isDeprecated: m['isDeprecated'],
        parameter: m['parameter'],
        propagatedType: m['propagatedType'],
        staticType: m['staticType']);
  }

  final int offset;
  final int length;
  @optional
  final String containingLibraryPath;
  @optional
  final String containingLibraryName;
  @optional
  final String containingClassDescription;
  @optional
  final String dartdoc;
  @optional
  final String elementDescription;
  @optional
  final String elementKind;
  @optional
  final bool isDeprecated;
  @optional
  final String parameter;
  @optional
  final String propagatedType;
  @optional
  final String staticType;

  HoverInformation(this.offset, this.length,
      {this.containingLibraryPath,
      this.containingLibraryName,
      this.containingClassDescription,
      this.dartdoc,
      this.elementDescription,
      this.elementKind,
      this.isDeprecated,
      this.parameter,
      this.propagatedType,
      this.staticType});
}

class ImplementedClass {
  static ImplementedClass parse(Map m) {
    if (m == null) return null;
    return new ImplementedClass(m['offset'], m['length']);
  }

  final int offset;
  final int length;

  ImplementedClass(this.offset, this.length);
}

class ImplementedMember {
  static ImplementedMember parse(Map m) {
    if (m == null) return null;
    return new ImplementedMember(m['offset'], m['length']);
  }

  final int offset;
  final int length;

  ImplementedMember(this.offset, this.length);
}

class LinkedEditGroup {
  static LinkedEditGroup parse(Map m) {
    if (m == null) return null;
    return new LinkedEditGroup(
        m['positions'] == null
            ? null
            : new List.from(m['positions'].map((obj) => Position.parse(obj))),
        m['length'],
        m['suggestions'] == null
            ? null
            : new List.from(m['suggestions']
                .map((obj) => LinkedEditSuggestion.parse(obj))));
  }

  final List<Position> positions;
  final int length;
  final List<LinkedEditSuggestion> suggestions;

  LinkedEditGroup(this.positions, this.length, this.suggestions);

  String toString() =>
      '[LinkedEditGroup positions: ${positions}, length: ${length}, suggestions: ${suggestions}]';
}

class LinkedEditSuggestion {
  static LinkedEditSuggestion parse(Map m) {
    if (m == null) return null;
    return new LinkedEditSuggestion(m['value'], m['kind']);
  }

  final String value;
  final String kind;

  LinkedEditSuggestion(this.value, this.kind);
}

class Location {
  static Location parse(Map m) {
    if (m == null) return null;
    return new Location(
        m['file'], m['offset'], m['length'], m['startLine'], m['startColumn']);
  }

  final String file;
  final int offset;
  final int length;
  final int startLine;
  final int startColumn;

  Location(
      this.file, this.offset, this.length, this.startLine, this.startColumn);

  operator ==(o) =>
      o is Location &&
      file == o.file &&
      offset == o.offset &&
      length == o.length &&
      startLine == o.startLine &&
      startColumn == o.startColumn;

  get hashCode =>
      file.hashCode ^
      offset.hashCode ^
      length.hashCode ^
      startLine.hashCode ^
      startColumn.hashCode;

  String toString() =>
      '[Location file: ${file}, offset: ${offset}, length: ${length}, startLine: ${startLine}, startColumn: ${startColumn}]';
}

class NavigationRegion {
  static NavigationRegion parse(Map m) {
    if (m == null) return null;
    return new NavigationRegion(m['offset'], m['length'],
        m['targets'] == null ? null : new List.from(m['targets']));
  }

  final int offset;
  final int length;
  final List<int> targets;

  NavigationRegion(this.offset, this.length, this.targets);

  String toString() =>
      '[NavigationRegion offset: ${offset}, length: ${length}, targets: ${targets}]';
}

class NavigationTarget {
  static NavigationTarget parse(Map m) {
    if (m == null) return null;
    return new NavigationTarget(m['kind'], m['fileIndex'], m['offset'],
        m['length'], m['startLine'], m['startColumn']);
  }

  final String kind;
  final int fileIndex;
  final int offset;
  final int length;
  final int startLine;
  final int startColumn;

  NavigationTarget(this.kind, this.fileIndex, this.offset, this.length,
      this.startLine, this.startColumn);

  String toString() =>
      '[NavigationTarget kind: ${kind}, fileIndex: ${fileIndex}, offset: ${offset}, length: ${length}, startLine: ${startLine}, startColumn: ${startColumn}]';
}

class Occurrences {
  static Occurrences parse(Map m) {
    if (m == null) return null;
    return new Occurrences(Element.parse(m['element']),
        m['offsets'] == null ? null : new List.from(m['offsets']), m['length']);
  }

  final Element element;
  final List<int> offsets;
  final int length;

  Occurrences(this.element, this.offsets, this.length);
}

class Outline {
  static Outline parse(Map m) {
    if (m == null) return null;
    return new Outline(Element.parse(m['element']), m['offset'], m['length'],
        children: m['children'] == null
            ? null
            : new List.from(m['children'].map((obj) => Outline.parse(obj))));
  }

  final Element element;
  final int offset;
  final int length;
  @optional
  final List<Outline> children;

  Outline(this.element, this.offset, this.length, {this.children});
}

class Override {
  static Override parse(Map m) {
    if (m == null) return null;
    return new Override(m['offset'], m['length'],
        superclassMember: OverriddenMember.parse(m['superclassMember']),
        interfaceMembers: m['interfaceMembers'] == null
            ? null
            : new List.from(m['interfaceMembers']
                .map((obj) => OverriddenMember.parse(obj))));
  }

  final int offset;
  final int length;
  @optional
  final OverriddenMember superclassMember;
  @optional
  final List<OverriddenMember> interfaceMembers;

  Override(this.offset, this.length,
      {this.superclassMember, this.interfaceMembers});
}

class OverriddenMember {
  static OverriddenMember parse(Map m) {
    if (m == null) return null;
    return new OverriddenMember(Element.parse(m['element']), m['className']);
  }

  final Element element;
  final String className;

  OverriddenMember(this.element, this.className);
}

class Position {
  static Position parse(Map m) {
    if (m == null) return null;
    return new Position(m['file'], m['offset']);
  }

  final String file;
  final int offset;

  Position(this.file, this.offset);

  String toString() => '[Position file: ${file}, offset: ${offset}]';
}

class PubStatus {
  static PubStatus parse(Map m) {
    if (m == null) return null;
    return new PubStatus(m['isListingPackageDirs']);
  }

  final bool isListingPackageDirs;

  PubStatus(this.isListingPackageDirs);

  String toString() =>
      '[PubStatus isListingPackageDirs: ${isListingPackageDirs}]';
}

class RefactoringMethodParameter {
  static RefactoringMethodParameter parse(Map m) {
    if (m == null) return null;
    return new RefactoringMethodParameter(m['kind'], m['type'], m['name'],
        id: m['id'], parameters: m['parameters']);
  }

  final String kind;
  final String type;
  final String name;
  @optional
  final String id;
  @optional
  final String parameters;

  RefactoringMethodParameter(this.kind, this.type, this.name,
      {this.id, this.parameters});
}

class RefactoringProblem {
  static RefactoringProblem parse(Map m) {
    if (m == null) return null;
    return new RefactoringProblem(m['severity'], m['message'],
        location: Location.parse(m['location']));
  }

  final String severity;
  final String message;
  @optional
  final Location location;

  RefactoringProblem(this.severity, this.message, {this.location});
}

abstract class ContentOverlayType {
  final String type;

  ContentOverlayType(this.type);
}

class RemoveContentOverlay extends ContentOverlayType implements Jsonable {
//  static RemoveContentOverlay parse(Map m) {
//    if (m == null) return null;
//    return new RemoveContentOverlay(m['type']);
//  }

  RemoveContentOverlay() : super('remove');

  Map toMap() => _stripNullValues({'type': type});
}

class SearchResult {
  static SearchResult parse(Map m) {
    if (m == null) return null;
    return new SearchResult(
        Location.parse(m['location']),
        m['kind'],
        m['isPotential'],
        m['path'] == null
            ? null
            : new List.from(m['path'].map((obj) => Element.parse(obj))));
  }

  final Location location;
  final String kind;
  final bool isPotential;
  final List<Element> path;

  SearchResult(this.location, this.kind, this.isPotential, this.path);

  String toString() =>
      '[SearchResult location: ${location}, kind: ${kind}, isPotential: ${isPotential}, path: ${path}]';
}

class SourceChange {
  static SourceChange parse(Map m) {
    if (m == null) return null;
    return new SourceChange(
        m['message'],
        m['edits'] == null
            ? null
            : new List.from(m['edits'].map((obj) => SourceFileEdit.parse(obj))),
        m['linkedEditGroups'] == null
            ? null
            : new List.from(
                m['linkedEditGroups'].map((obj) => LinkedEditGroup.parse(obj))),
        selection: Position.parse(m['selection']));
  }

  final String message;
  final List<SourceFileEdit> edits;
  final List<LinkedEditGroup> linkedEditGroups;
  @optional
  final Position selection;

  SourceChange(this.message, this.edits, this.linkedEditGroups,
      {this.selection});

  String toString() =>
      '[SourceChange message: ${message}, edits: ${edits}, linkedEditGroups: ${linkedEditGroups}]';
}

class SourceEdit implements Jsonable {
  static SourceEdit parse(Map m) {
    if (m == null) return null;
    return new SourceEdit(m['offset'], m['length'], m['replacement'],
        id: m['id']);
  }

  final int offset;
  final int length;
  final String replacement;
  @optional
  final String id;

  Map toMap() => _stripNullValues({
        'offset': offset,
        'length': length,
        'replacement': replacement,
        'id': id
      });

  SourceEdit(this.offset, this.length, this.replacement, {this.id});

  String toString() =>
      '[SourceEdit offset: ${offset}, length: ${length}, replacement: ${replacement}]';
}

class SourceFileEdit {
  static SourceFileEdit parse(Map m) {
    if (m == null) return null;
    return new SourceFileEdit(
        m['file'],
        m['fileStamp'],
        m['edits'] == null
            ? null
            : new List.from(m['edits'].map((obj) => SourceEdit.parse(obj))));
  }

  final String file;
  final int fileStamp;
  final List<SourceEdit> edits;

  SourceFileEdit(this.file, this.fileStamp, this.edits);

  String toString() =>
      '[SourceFileEdit file: ${file}, fileStamp: ${fileStamp}, edits: ${edits}]';
}

class TypeHierarchyItem {
  static TypeHierarchyItem parse(Map m) {
    if (m == null) return null;
    return new TypeHierarchyItem(
        Element.parse(m['classElement']),
        m['interfaces'] == null ? null : new List.from(m['interfaces']),
        m['mixins'] == null ? null : new List.from(m['mixins']),
        m['subclasses'] == null ? null : new List.from(m['subclasses']),
        displayName: m['displayName'],
        memberElement: Element.parse(m['memberElement']),
        superclass: m['superclass']);
  }

  final Element classElement;
  final List<int> interfaces;
  final List<int> mixins;
  final List<int> subclasses;
  @optional
  final String displayName;
  @optional
  final Element memberElement;
  @optional
  final int superclass;

  TypeHierarchyItem(
      this.classElement, this.interfaces, this.mixins, this.subclasses,
      {this.displayName, this.memberElement, this.superclass});
}

// refactorings

class Refactorings {
  static const String CONVERT_GETTER_TO_METHOD = 'CONVERT_GETTER_TO_METHOD';
  static const String CONVERT_METHOD_TO_GETTER = 'CONVERT_METHOD_TO_GETTER';
  static const String EXTRACT_LOCAL_VARIABLE = 'EXTRACT_LOCAL_VARIABLE';
  static const String EXTRACT_METHOD = 'EXTRACT_METHOD';
  static const String INLINE_LOCAL_VARIABLE = 'INLINE_LOCAL_VARIABLE';
  static const String INLINE_METHOD = 'INLINE_METHOD';
  static const String MOVE_FILE = 'MOVE_FILE';
  static const String RENAME = 'RENAME';
}

class ExtractLocalVariableRefactoringOptions extends RefactoringOptions {
  final String name;
  final bool extractAll;

  ExtractLocalVariableRefactoringOptions({this.name, this.extractAll});

  Map toMap() => _stripNullValues({'name': name, 'extractAll': extractAll});
}

class ExtractMethodRefactoringOptions extends RefactoringOptions {
  final String returnType;
  final bool createGetter;
  final String name;
  final List<RefactoringMethodParameter> parameters;
  final bool extractAll;

  ExtractMethodRefactoringOptions(
      {this.returnType,
      this.createGetter,
      this.name,
      this.parameters,
      this.extractAll});

  Map toMap() => _stripNullValues({
        'returnType': returnType,
        'createGetter': createGetter,
        'name': name,
        'parameters': parameters,
        'extractAll': extractAll
      });
}

class InlineMethodRefactoringOptions extends RefactoringOptions {
  final bool deleteSource;
  final bool inlineAll;

  InlineMethodRefactoringOptions({this.deleteSource, this.inlineAll});

  Map toMap() =>
      _stripNullValues({'deleteSource': deleteSource, 'inlineAll': inlineAll});
}

class MoveFileRefactoringOptions extends RefactoringOptions {
  final String newFile;

  MoveFileRefactoringOptions({this.newFile});

  Map toMap() => _stripNullValues({'newFile': newFile});
}

class RenameRefactoringOptions extends RefactoringOptions {
  final String newName;

  RenameRefactoringOptions({this.newName});

  Map toMap() => _stripNullValues({'newName': newName});
}

// EXTRACT_LOCAL_VARIABLE:
//   @optional coveringExpressionOffsets → List<int>
//   @optional coveringExpressionLengths → List<int>
//   names → List<String>
//   offsets → List<int>
//   lengths → List<int>

// EXTRACT_METHOD:
//   offset → int
//   length → int
//   returnType → String
//   names → List<String>
//   canCreateGetter → bool
//   parameters → List<RefactoringMethodParameter>
//   offsets → List<int>
//   lengths → List<int>

// INLINE_LOCAL_VARIABLE:
//   name → String
//   occurrences → int

// INLINE_METHOD:
//   @optional className → String
//   methodName → String
//   isDeclaration → bool

// RENAME:
//   offset → int
//   length → int
//   elementKindName → String
//   oldName → String

class RefactoringFeedback {
  static RefactoringFeedback parse(Map m) {
    return m == null ? null : new RefactoringFeedback(m);
  }

  final Map _m;

  RefactoringFeedback(this._m);

  operator [](String key) => _m[key];
}
