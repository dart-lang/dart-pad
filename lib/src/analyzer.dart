// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer;

import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' hide Logger;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:logging/logging.dart';

import 'api_classes.dart';
import 'common.dart';
import 'pub.dart';

Logger _logger = new Logger('analyzer');

class MemoryResolver extends UriResolver {
  Map<String, Source> sources = {};

  @override
  Source resolveAbsolute(Uri uri) {
    return sources[uri.toString()];
  }

  void addFileToMap(StringSource file) {
    sources[file.fullName] = file;
  }

  void clear() => sources.clear();
}

class Analyzer {
  final Pub pub;
  AnalysisContext _context;
  MemoryResolver _resolver;
  String _sdkPath;

  Analyzer(this._sdkPath, [this.pub]) {
    _reset();
    analyze('');
  }

  void _reset() {
    _resolver = new MemoryResolver();

    DartSdk sdk = new DirectoryBasedDartSdk(new JavaFile(_sdkPath),
    /*useDart2jsPaths*/ true);
    _context = AnalysisEngine.instance.createAnalysisContext();
    _context.analysisOptions = new AnalysisOptionsImpl()..cacheSize = 512;

    List<UriResolver> resolvers = [
      new DartUriResolver(sdk),
      _resolver
      // TODO: Create a new UriResolver.
      //new PackageUriResolver([new JavaFile(project.packagePath)
    ];
    _context.sourceFactory = new SourceFactory(resolvers);
    AnalysisEngine.instance.logger = new NullLogger();
  }

  Future warmup([bool useHtml = false]) =>
      analyze(useHtml ? sampleCodeWeb : sampleCode);

  Future<AnalysisResults> analyze(String source) {
    return analyzeMulti({"main.dart" : source});
  }

  Future<AnalysisResults> analyzeMulti(Map<String, String> sources) {
    try {
      List<StringSource> sourcesList = <StringSource>[];
      for (String name in sources.keys) {
        StringSource src = new StringSource(sources[name], name);
        _resolver.addFileToMap(src);
        sourcesList.add(src);
      }

      ChangeSet changeSet = new ChangeSet();
      sourcesList.forEach((s) => changeSet.addedSource(s));
      _context.applyChanges(changeSet);

      List<AnalysisErrorInfo> errorInfos = [];
      sourcesList.forEach((s) {
        _context.computeErrors(s);
        errorInfos.add(_context.getErrors(s));
      });

      List<_Error> errors = errorInfos.expand((AnalysisErrorInfo info) {
        return info.errors.map((error) => new _Error(error, info.lineInfo));
      }).where((_Error error) => error.errorType != ErrorType.TODO).toList();

      // Calculate the issues.
      List<AnalysisIssue> issues = errors.map((_Error error) {
        return new AnalysisIssue.fromIssue(
            error.severityName, error.line, error.message,
            location: error.location,
            charStart: error.offset, charLength: error.length,
            sourcePath: error.error.source.fullName,
            hasFixes: error.probablyHasFix);
      }).toList();
      issues.sort();

      // Calculate the imports.
      Set<String> packageImports = new Set();
      for (String source in sources.values) {
        // TODO: Use the `pub` object for this in the future.
        packageImports.addAll(
            filterSafePackagesFromImports(getAllUnsafeImportsFor(source)));
      }
      List<String> resolvedImports = _calculateImports(_context, sourcesList);

      // Delete the files
      changeSet = new ChangeSet();
      sourcesList.forEach((s) => changeSet.deletedSource(s));
      _resolver.clear();
      _context.applyChanges(changeSet);

      return new Future.value(new AnalysisResults(
          issues, packageImports.toList(), resolvedImports));
    } catch (e, st) {
      _reset();
      return new Future.error(e, st);
    }
  }

  Future<Map<String, String>> dartdoc(String source, int offset) {
    try {
      var _source = new StringSource(source, "main.dart");

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
        info['description'] = '${_prettifyElement(element)}';
        info['kind'] = element.kind.displayName;

        // Only defined if there is an enclosing class.
        if (element.enclosingElement is ClassElement) {
          info['enclosingClassName'] = '${element.enclosingElement}';
        } else {
          info['enclosingClassName'] = null;
        }

        // Parameters for functions and methods.
        if (element is ExecutableElement) {
          List<String> list = [];
          ExecutableElement el = element;
          el.parameters.forEach((par)
            => list.add('${_prettifyElement(par)}'));
          info['parameters'] = list;
        }

        // library
        LibraryElement library = element.library;

        if (library != null) {
          if (library.name != null && library.name.isNotEmpty) {
            // TODO(lukechurch) remove this once this bug is fixed
            if (library.location.toString() != "utf-8") {
              info['libraryName'] = '${library.location}';
            } else {
              info['libraryName'] = library.name;
            }
          }
          if (library.location.toString() == "dart:html") {
            for (ElementAnnotationImpl e in element.metadata) {
              if (e.toString().startsWith("@DomName")) {
                EvaluationResultImpl evaluationResult = e.evaluationResult;
                if (evaluationResult != null && evaluationResult.value.fields["name"] != null) {
                  info["DomName"] = evaluationResult.value.fields["name"].value;
                } else {
                  _logger.fine("WARNING: Unexpected null, aborting");
                }
                break;
              }
            }
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
        info['staticType'] = '${_prettifyType(expression.staticType)}';
      }

      if (expression.propagatedType != null) {
        info['propagatedType'] = '${_prettifyType(expression.propagatedType)}';
      }

      return info;
    }

    return null;
  }

  /// Calculate the resolved imports for the given set of sources.
  List<String> _calculateImports(AnalysisContext context, List<Source> sources) {
    Set<String> imports = new Set();

    for (Source source in sources) {
      LibraryElement element = context.getLibraryElement(source);

      if (element != null) {
        element.imports.forEach((ImportElement import) {
          // The dart:core implicit import has a null uri.
          if (import.uri != null) imports.add(import.uri);
        });
      }
    }

    return imports.toList();
  }

  // TODO(lukechurch): Determine whether we can change this in the Analyzer.
  static String _prettifyElement(Element e) {
    String returnString = "${e}";
    returnString = returnString.replaceAll("Future<dynamic>", "Future");
    return returnString;
  }

  static String _prettifyType(DartType dt) {
    String returnString = "${dt}";
    returnString = returnString.replaceAll("Future<dynamic>", "Future");
    return returnString;
  }
}

/// An implementation of [Source] that is based on an in-memory string.
class StringSource implements Source {
  final String fullName;

  int _modificationStamp;
  String _contents;

  StringSource(this._contents, this.fullName)
      : _modificationStamp = new DateTime.now().millisecondsSinceEpoch;

  void updateSource(String newSource) {
    _contents = newSource;
    _modificationStamp = new DateTime.now().millisecondsSinceEpoch;
  }

  int get modificationStamp => _modificationStamp;

  bool operator==(Object object) {
    if (object is StringSource) {
      StringSource ssObject = object;
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

  Uri get uri {
    throw new UnsupportedError("StringSource doesn't support uri.");
  }

  // TODO: I don't think this is generally sufficent, but it meets our purposes
  // here.
  Uri resolveRelativeUri(Uri relativeUri) {
    return relativeUri;
  }

  @override
  Source get source => this;
}

class _Error {
  static final _HAS_FIXES_WHITELIST = [
    HintCode.UNUSED_IMPORT,
    ParserErrorCode.EXPECTED_TOKEN,
    StaticWarningCode.UNDEFINED_IDENTIFIER,
    StaticWarningCode.UNDEFINED_CLASS,
    StaticWarningCode.UNDEFINED_CLASS_BOOLEAN,
  ];

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

  /// Heurestic for whether there is going to be a fix offered for this
  /// issue
  bool get probablyHasFix => _HAS_FIXES_WHITELIST.contains(error.errorCode);

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

    // Remove leading '* ' and '///'; don't remove a leading '*' if there is a
    // matching '*' in the line.
    if (line.startsWith('* ')) {
      line = line.substring(2);
    } else if (line.startsWith("*") && line.lastIndexOf('*') == 0) {
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
