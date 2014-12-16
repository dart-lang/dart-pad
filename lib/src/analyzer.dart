
library dartpad_serve.analyzer;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/java_io.dart';

import 'common.dart' hide DartSdk;

// TODO: a package resolver

class Analyzer {
  _StringSource _source;
  AnalysisContext _context;

  Analyzer(String sdkPath) {
    DartSdk sdk = new DirectoryBasedDartSdk(new JavaFile(sdkPath));
    _context = AnalysisEngine.instance.createAnalysisContext();
    _context.analysisOptions = new AnalysisOptionsImpl()..cacheSize = 512;
    List<UriResolver> resolvers = [new DartUriResolver(sdk)];
    // new FileUriResolver()
    // new PackageUriResolver([new JavaFile(project.packagePath)])
    _context.sourceFactory = new SourceFactory(resolvers);
    AnalysisEngine.instance.logger = new _Logger();

    _source = new _StringSource('', 'main.dart');

    ChangeSet changeSet = new ChangeSet();
    changeSet.addedSource(_source);
    _context.applyChanges(changeSet);
    _context.computeErrors(_source);
    _context.getErrors(_source);
  }

  Future warmup([bool useHtml = false]) =>
      analyze(useHtml ? sampleCodeWeb : sampleCode);

  Future<AnalysisResults> analyze(String source) {
    _source.updateSource(source);

    ChangeSet changeSet = new ChangeSet();
    changeSet.addedSource(_source);
    _context.applyChanges(changeSet);
    _context.computeErrors(_source);
    _context.getErrors(_source);

    List<AnalysisErrorInfo> errorInfos = [];

    _context.computeErrors(_source);
    errorInfos.add(_context.getErrors(_source));

    List<_Error> errors = errorInfos
      .expand((AnalysisErrorInfo info) {
        return info.errors.map((error) => new _Error(error, info.lineInfo));
      })
      .where((_Error error) => error.errorType != ErrorType.TODO)
      .toList();

    List<AnalysisIssue> issues = errors.map((_Error error) {
      return new AnalysisIssue(
          error.severityName, error.line, error.message,
          location: error.location,
          charStart: error.offset, charLength: error.length);
    }).toList();

    return new Future.value(new AnalysisResults(issues));
  }
}

class AnalysisResults {
  final List<AnalysisIssue> issues;

  AnalysisResults(this.issues);
}

class AnalysisIssue {
  final String kind;
  final int line;
  final String message;

  final int charStart;
  final int charLength;
  final String location;

  AnalysisIssue(this.kind, this.line, this.message,
      {this.charStart, this.charLength, this.location});

  Map toMap() {
    Map m = {'kind': kind, 'line': line, 'message': message};
    if (charStart != null) m['charStart'] = charStart;
    if (charLength != null) m['charLength'] = charLength;
    return m;
  }
}

/// An implementation of [Source] that's based on an in-memory Dart string.
class _StringSource implements Source {
  final String fullName;

  int _modificationStamp;
  String _contents;

  _StringSource(this._contents, this.fullName)
      : _modificationStamp = new DateTime.now().millisecondsSinceEpoch;

  void updateSource(String newSource) {
    _contents = newSource;
    _modificationStamp = new DateTime.now().millisecondsSinceEpoch;
  }

  int get modificationStamp => _modificationStamp;

  bool operator==(Object object) {
    if (object is _StringSource) {
      _StringSource ssObject = object;
      return ssObject._contents == _contents && ssObject.fullName == fullName;
    }
    return false;
  }

  bool exists() => true;

  TimestampedData<String> get contents => new TimestampedData(modificationStamp, _contents);

  String get encoding => throw new UnsupportedError("StringSource doesn't support "
      "encoding.");

  String get shortName => fullName;

  UriKind get uriKind => throw new UnsupportedError("StringSource doesn't support "
      "uriKind.");

  int get hashCode => _contents.hashCode ^ fullName.hashCode;

  bool get isInSystemLibrary => false;

  @override
  Uri get uri => throw new UnsupportedError(
      "StringSource doesn't support uri.");

  Uri resolveRelativeUri(Uri relativeUri) => throw new UnsupportedError(
      "StringSource doesn't support resolveRelative.");
}

class _Logger extends Logger {
  void logError(String message) => stderr.writeln(message);
  void logError2(String message, dynamic exception) => stderr.writeln(message);
  void logInformation(String message) { }
  void logInformation2(String message, dynamic exception) { }
}

class _Error implements Comparable {
  final AnalysisError error;
  final LineInfo lineInfo;

  _Error(this.error, this.lineInfo);

  ErrorType get errorType => error.errorCode.type;
  int get severity => error.errorCode.errorSeverity.ordinal;
  String get severityName => error.errorCode.errorSeverity.displayName;
  String get message => error.message;
  String get description => '${message} at ${location}, line ${line}.';

  int get line => lineInfo.getLocation(error.offset).lineNumber;
  int get offset => error.offset;
  int get length => error.length;

  String get location => error.source.fullName;

  int compareTo(_Error other) {
    if (severity == other.severity) {
      int cmp = error.source.fullName.compareTo(other.error.source.fullName);
      return cmp == 0 ? line - other.line : cmp;
    } else {
      return other.severity - severity;
    }
  }

  String toString() => '[${severityName}] ${description}';
}
