// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:analyzer/src/generated/constant.dart';
// ignore: deprecated_member_use
import 'package:analyzer/src/generated/element.dart' show ElementAnnotationImpl;
import 'package:analyzer/src/generated/engine.dart' hide Logger;
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/sdk.dart' as gen_sdk;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'api_classes.dart';
import 'common.dart';
import 'pub.dart';

Logger _logger = new Logger('analyzer');

final Duration _MAX_ANALYSIS_DURATION = new Duration(seconds: 10);

class Analyzer {
  final Pub pub;
  bool strongMode;
  AnalysisContext _context;
  String _sdkPath;
  Directory _sourceDirectory;

  ContentCache cache;

  Analyzer(this._sdkPath, {this.pub, this.strongMode: false}) {
    _reset();
  }

  void _reset() {
    this.cache = new ContentCache();

    _sourceDirectory = Directory.systemTemp.createTempSync('analyzer');

    PhysicalResourceProvider physicalResourceProvider =
        PhysicalResourceProvider.INSTANCE;

    AnalysisOptionsImpl analysisOptions = new AnalysisOptionsImpl();
    analysisOptions.strongMode = strongMode;

    ContextBuilderOptions builderOptions = new ContextBuilderOptions();
    builderOptions.defaultOptions = analysisOptions;

    var sdkManager =
        new gen_sdk.DartSdkManager(_sdkPath, true, (AnalysisOptions options) {
      FolderBasedDartSdk sdk = new FolderBasedDartSdk(physicalResourceProvider,
          physicalResourceProvider.getFolder(_sdkPath));
      sdk.analysisOptions = options;
    });

    // MemoryResourceProvider memResourceProvider = new MemoryResourceProvider();
    var builder = new ContextBuilder(
        physicalResourceProvider, sdkManager, cache,
        options: builderOptions);

    // builder.fileResolverProvider = (folder) {
    //   print (folder);
    //   return _resolver;
    // };

    _context = builder.buildContext(_sourceDirectory.path);

    // _context.analysisOptions = options;

    // List<UriResolver> resolvers = [
    //   new DartUriResolver(sdk),
    //   _resolver
    //   // TODO: Create a new UriResolver.
    //   //new PackageUriResolver([new JavaFile(project.packagePath)
    // ];
    // _context.sourceFactory = new SourceFactory(resolvers);
    AnalysisEngine.instance.logger = new NullLogger();
  }

  Future warmup({bool useHtml: false}) =>
      analyze(useHtml ? sampleCodeWeb : sampleCode);

  Future<AnalysisResults> analyze(String source) {
    return analyzeMulti({kMainDart: source});
  }

  Future<AnalysisResults> analyzeMulti(Map<String, String> sources) {
    try {
      String pathPrefix = _sourceDirectory.path;
      List<StringSource> sourcesList = <StringSource>[];
      for (String name in sources.keys) {
        String path = name.startsWith('/') ? name : '$pathPrefix/$name';
        StringSource src = new StringSource(sources[name], path);
        // _resolver.addFileToMap(src);
        sourcesList.add(src);
      }

      ChangeSet changeSet = new ChangeSet();
      sourcesList.forEach((s) {
        changeSet.addedSource(s);
        changeSet.changedContent(s, s.contents.data);
      });
      _context.applyChanges(changeSet);
      _ensureAnalysisDone(_context, _MAX_ANALYSIS_DURATION);

      List<AnalysisErrorInfo> errorInfos = [];
      sourcesList.forEach((s) {
        _context.computeErrors(s);
        errorInfos.add(_context.getErrors(s));
      });

      List<_Error> errors = errorInfos
          .expand((AnalysisErrorInfo info) {
            return info.errors.map((error) => new _Error(error, info.lineInfo));
          })
          .where((_Error error) => error.errorType != ErrorType.TODO)
          .toList();

      // Calculate the issues.
      List<AnalysisIssue> issues = errors.map((_Error error) {
        return new AnalysisIssue.fromIssue(
            error.severityName, error.line, error.message,
            charStart: error.offset,
            charLength: error.length,
            sourceName: path.basename(error.error.source.fullName),
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

      // Delete the files
      changeSet = new ChangeSet();
      sourcesList.forEach((s) {
        changeSet.changedContent(s, null);
        changeSet.removedSource(s);
      });
      // Remove sources implicitly created by imports of non-existing files
      changeSet.removedContainer(new _SourceContainer(pathPrefix));
      // _resolver.clear();
      _context.applyChanges(changeSet);
      _ensureAnalysisDone(_context, _MAX_ANALYSIS_DURATION);

      return new Future.value(
          new AnalysisResults(issues, packageImports.toList()));
    } catch (e, st) {
      _reset();
      return new Future.error(e, st);
    }
  }

  /// Ensure that the Analysis engine completes all remaining work. If a
  /// timeout is supplied, try to throw an exception if the time is
  /// exceeded. This may not happen if a single call to performAnalysisTask
  /// takes a long time.
  void _ensureAnalysisDone(AnalysisContext context, [Duration timeout]) {
    Stopwatch sw = new Stopwatch()..start();

    AnalysisResult result = context.performAnalysisTask();
    while (result.hasMoreWork) {
      if (timeout != null && sw.elapsed > timeout) {
        throw new TimeoutException(
            "_ensureAnalysisDone exceeeded allowed time");
      }
      result = context.performAnalysisTask();
    }
  }

  @deprecated
  Future<Map<String, String>> dartdoc(String source, int offset) {
    try {
      var _source = new StringSource(source, kMainDart);

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
    AstNode node = new NodeLocator(offset).searchWithin(unit);

    if (node == null) return null;

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
      Map<String, dynamic> info = {};

      // element
      NodeLocator locator = new NodeLocator(offset);
      Element element = ElementLocator.locate(locator.searchWithin(expression));

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
        }

        // Parameters for functions and methods.
        if (element is ExecutableElement) {
          List<String> list = [];
          ExecutableElement el = element;
          el.parameters.forEach((par) => list.add('${_prettifyElement(par)}'));
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
            for (ElementAnnotationImpl annotationElement in element.metadata) {
              if (annotationElement.toString().startsWith("@DomName")) {
                // In order for this to reliably return a result, the compilation
                // unit would need to be resolved.
                EvaluationResultImpl evaluationResult =
                    annotationElement.evaluationResult;
                if (evaluationResult != null &&
                    evaluationResult.value.fields["name"] != null) {
                  info["DomName"] =
                      evaluationResult.value.fields["name"].toStringValue();
                } else {
                  _logger.fine("WARNING: Unexpected null, aborting");
                }
                break;
              }
            }
          }
        }

        // documentation
        String dartDoc = element.documentationComment;
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

  // TODO(lukechurch): Determine whether we can change this in the Analyzer.
  static String _prettifyElement(Element element) =>
      '$element'.replaceAll("Future<dynamic>", "Future");

  static String _prettifyType(DartType type) =>
      '$type'.replaceAll("Future<dynamic>", "Future");
}

class _SourceContainer implements SourceContainer {
  final String pathPrefix;

  _SourceContainer(this.pathPrefix);

  @override
  bool contains(Source source) => source.fullName.startsWith(pathPrefix);
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

  /// Heuristic for whether there is going to be a fix offered for this
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
