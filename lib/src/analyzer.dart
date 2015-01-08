// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.analyzer;

import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' hide Logger;
import 'package:analyzer/src/generated/engine.dart' as engine show Logger;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:logging/logging.dart';

import 'common.dart';

Logger _logger = new Logger('analyzer');

class Analyzer {
  _StringSource _source;
  AnalysisContext _context;

  Analyzer(String sdkPath) {
    DartSdk sdk = new DirectoryBasedDartSdk(new JavaFile(sdkPath),
        /*useDart2jsPaths*/ true);
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
    try {
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

      issues.sort();

      return new Future.value(new AnalysisResults(issues));
    } catch (e, st) {
      return new Future.error(e, st);
    }
  }

  Future<Map<String, String>> dartdoc(String source, int offset) {
    try {
      _source.updateSource(source);

      ChangeSet changeSet = new ChangeSet();
      changeSet.addedSource(_source);
      _context.applyChanges(changeSet);

      LibraryElement library = _context.computeLibraryElement(_source);
      CompilationUnit unit = _context.resolveCompilationUnit(_source, library);
      return new Future.value(_computeDartdocInfo(unit, offset));
    } catch (e, st) {
      return new Future.error(e, st);
    }
  }

  Map<String, String> _computeDartdocInfo(CompilationUnit unit, int offset) {
    AstNode node = new NodeLocator.con1(offset).searchWithin(unit);

    if (node.parent is TypeName &&
        node.parent.parent is ConstructorName &&
        node.parent.parent.parent is InstanceCreationExpression) {
      node = node.parent.parent.parent;
    }

    if (node.parent is ConstructorName &&
        node.parent.parent is InstanceCreationExpression) {
      node = node.parent.parent;
    }

    if (node is Expression) {
      Expression expression = node;
      Map info = {};

      // element
      Element element = ElementLocator.locateWithOffset(expression, offset);

      if (element != null) {
        // variable, if synthetic accessor
        if (element is PropertyAccessorElement) {
          PropertyAccessorElement accessor = element;
          if (accessor.isSynthetic) element = accessor.variable;
        }

        // Name and description.
        if (element.name != null) info['name'] = element.name;
        //if (element.displayName != null) info['displayName'] = element.displayName;
        info['description'] = '${element}';
        info['kind'] = element.kind.displayName;

        // library
        LibraryElement library = element.library;

        if (library != null) {
          if (library.name != null && library.name.isNotEmpty) {
            info['libraryName'] = library.name;
          }
          //info['libraryPath'] = library.source.shortName;
        }

        // documentation
        String dartDoc = element.computeDocumentationComment();
        dartDoc = cleanDartDoc(dartDoc);
        if (dartDoc != null) info['dartdoc'] = dartDoc;
      }

      // types
      if (expression.staticType != null) {
        info['staticType'] = '${expression.staticType}';
      }

      if (expression.propagatedType != null) {
        info['propagatedType'] = '${expression.propagatedType}';
      }

      return info;
    }

    return null;
  }
}

class AnalysisResults {
  final List<AnalysisIssue> issues;

  AnalysisResults(this.issues);
}

class AnalysisIssue implements Comparable {
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

  int compareTo(AnalysisIssue other) => line - other.line;
}

/// An implementation of [Source] that is based on an in-memory string.
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

  String get encoding => 'utf-8';

  String get shortName => fullName;

  UriKind get uriKind => UriKind.FILE_URI;

  int get hashCode => fullName.hashCode;

  bool get isInSystemLibrary => false;

  Uri get uri => throw new UnsupportedError("StringSource doesn't support uri.");

  Uri resolveRelativeUri(Uri relativeUri) =>
      throw new AnalysisException("Cannot resolve a URI: ${relativeUri}");
}

class _Logger extends engine.Logger {
  void logError(String message) => _logger.severe(message);

  void logError2(String message, dynamic exception) =>
      _logger.severe(message, exception);

  void logInformation(String message) { }

  void logInformation2(String message, dynamic exception) { }
}

class _Error {
  final AnalysisError error;
  final LineInfo lineInfo;

  _Error(this.error, this.lineInfo);

  ErrorType get errorType => error.errorCode.type;
  String get severityName => error.errorCode.errorSeverity.displayName;
  String get message => error.message;

  int get line => lineInfo.getLocation(error.offset).lineNumber;
  int get offset => error.offset;
  int get length => error.length;

  String get location => error.source.fullName;

  String toString() => '${message} at ${location}, line ${line}.';
}

/**
 * Converts [str] from a Dartdoc string with slashes and stars to a plain text
 * representation of the comment.
 */
String cleanDartDoc(String str) {
  if (str == null) return null;

  // Remove /** */.
  str = str.trim();
  if (str.startsWith('/**')) str = str.substring(3);
  if (str.endsWith("*/")) str = str.substring(0, str.length - 2);
  str = str.trim();

  // Remove leading '* '.
  StringBuffer sb = new StringBuffer();
  bool firstLine = true;

  for (String line in str.split('\n')) {
    line = line.trim();

    if (line.startsWith("*")) {
      line = line.substring(1);
      if (line.startsWith(" ")) line = line.substring(1);
    } else if (line.startsWith("///")) {
      line = line.substring(3);
      if (line.startsWith(" ")) line = line.substring(1);
    }

    if (!firstLine) sb.write('\n');
    firstLine = false;
    sb.write(line);
  }

  return sb.toString();
}
