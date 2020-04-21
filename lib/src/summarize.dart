// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.summarize;

import 'package:crypto/crypto.dart';

import 'protos/dart_services.pb.dart' as proto;

/// Instances of this class take string input of dart code as well as an
/// analysis result, and output a text description ofthe code's size, packages,
/// and other useful information.
class Summarizer {
  final String dart;
  final String html;
  final String css;
  final proto.AnalysisResults analysis;

  _SummarizeToken storage;
  int _randomizer;

  static Map<String, List<int>> cuttoffs = <String, List<int>>{
    'size': <int>[8, 30, 1000], //0-7 = small, 8 - 29 = decent, 29+ = gigantic
    'errorCount': <int>[1, 10, 100]
  };

  static Map<String, String> codeKeyWords = <String, String>{
    'await': 'await',
    'async': 'async',
    'rpc': 'RESTful serverside app'
  };

  static Map<String, String> additionKeyWords = <String, String>{
    'pirate': 'pirates',
    'bird': 'birds',
    'llama': 'llamas',
    'dog': 'dogs'
  };

  static Map<String, List<String>> categories = <String, List<String>>{
    /// This [size] [codeQuantifier] contains [error] errors and warnings.
    'size-2': <String>[
      'gigantic',
      'Jupiterian sized',
      'immense',
      'massive',
      'enormous',
      'huge',
      'epic',
      'humongous'
    ],
    'size-1': <String>[
      'decently sized',
      'exceptional',
      'awesome',
      'amazing',
      'visionary',
      'legendary'
    ],
    'size-0': <String>['itty-bitty', 'miniature', 'tiny', 'pint-sized'],
    'compiledQuantifier': <String>['Dart program', 'pad'],
    'failedQuantifier': <String>[
      'assemblage of characters',
      'series of strings',
      'grouping of letters'
    ],
    'errorCount-2': <String>[
      'many',
      'a motherload of',
      'copious amounts of',
      'unholy quantities of'
    ],
    'errorCount-1': <String>[
      'some',
      'a few',
      'sparse amounts of',
      'very few instances of'
    ],
    'errorCount-0': <String>['zero', 'no', 'a nonexistent amount of', '0'],
    'use': <String>['demonstrates', 'illustrates', 'depicts'],
    'code-0': <String>['it'],
    'code-1': <String>['It'],
  };

  Summarizer({this.dart, this.html, this.css, this.analysis}) {
    if (dart == null) throw ArgumentError('Input cannot be null.');
    _randomizer = _sumList(md5.convert(dart.codeUnits).bytes);
    storage = _SummarizeToken(dart, analysis: analysis);
  }

  bool get hasAnalysisResults => analysis != null;

  int _sumList(List<int> list) => list.reduce((int a, int b) => a + b);

  String _categorySelector(String category, int itemCount) {
    if (category == 'size' || category == 'errorCount') {
      final maxField = cuttoffs[category];
      for (var counter = 0; counter < maxField.length; counter++) {
        if (itemCount < maxField[counter]) return '$category-$counter';
      }
      return '$category-${maxField.length - 1}';
    } else {
      return null;
    }
  }

  String _wordSelector(String category) {
    if (categories.containsKey(category)) {
      final returnSet = categories[category];
      return returnSet.elementAt(_randomizer % returnSet.length);
    } else {
      return null;
    }
  }

  String _sentenceFiller(String word, [int size]) {
    if (size != null) {
      return _wordSelector(_categorySelector(word, size));
    } else {
      return _wordSelector(word);
    }
  }

  String _additionList(List<String> list) {
    if (list.isEmpty) return '';
    var englishList = ' Also, mentions ';
    for (var i = 0; i < list.length; i++) {
      englishList += list[i];
      if (i < list.length - 2) englishList += ', ';
      if (i == list.length - 2) {
        if (i != 0) englishList += ',';
        englishList += ' and ';
      }
    }
    englishList += '. ';
    return englishList;
    // TODO: Tokenize features instead of returning as string.
  }

  List<String> additionSearch() => _additionSearch();

  bool _usedInDartSource(String feature) => dart.contains(feature);

  List<String> _additionSearch() {
    final features = <String>[];
    for (final feature in additionKeyWords.keys) {
      if (_usedInDartSource(feature)) features.add(additionKeyWords[feature]);
    }
    return features;
  }

  List<String> _codeSearch() {
    final features = <String>[];
    for (final feature in codeKeyWords.keys) {
      if (_usedInDartSource(feature)) features.add(codeKeyWords[feature]);
    }
    return features;
  }

  String _featureList(List<String> list) {
    if (list.isEmpty) return '. ';
    var englishList = ', and ${_sentenceFiller('use')} use of ';
    for (var i = 0; i < list.length; i++) {
      englishList += list[i];
      if (i < list.length - 2) englishList += ', ';
      if (i == list.length - 2) {
        if (i != 0) englishList += ',';
        englishList += ' and ';
      }
    }
    englishList += ' features. ';
    return englishList;
  }

  String _packageList(List<String> list, {String source}) {
    if (list.isEmpty) {
      return source == null ? '' : '. ';
    }

    var englishList = '';
    if (source == 'packages') {
      englishList += ', and ${_sentenceFiller('code-0')} imports ';
    } else {
      englishList += '${_sentenceFiller('code-1')} imports the ';
    }

    for (var i = 0; i < list.length; i++) {
      englishList += "'${list[i]}'";
      if (i < list.length - 2) englishList += ', ';
      if (i == list.length - 2) {
        if (i != 0) englishList += ',';
        englishList += ' and ';
      }
    }

    if (source == 'packages') {
      englishList += ' from external packages. ';
    } else {
      englishList += ' packages as well. ';
    }

    return englishList;
  }

  String _htmlCSS() {
    var htmlCSS = 'This code has ';
    if (_hasCSS && _hasHtml) {
      htmlCSS += 'associated html and css';
      return htmlCSS;
    }
    if (!_hasCSS && !_hasHtml) {
      htmlCSS += 'no associated html or css';
      return htmlCSS;
    }
    if (!_hasHtml) {
      htmlCSS += 'no ';
    } else {
      htmlCSS += 'some ';
    }
    htmlCSS += 'associated html and ';
    if (!_hasCSS) {
      htmlCSS += 'no ';
    } else {
      htmlCSS += 'some ';
    }
    htmlCSS += 'associated css';
    return htmlCSS;
  }

  bool get _hasHtml => html != null && html.isNotEmpty;
  bool get _hasCSS => css != null && css.isNotEmpty;

  String returnAsSimpleSummary() {
    if (hasAnalysisResults) {
      var summary = '';
      summary += 'This ${_sentenceFiller('size', storage.linesCode)} ';
      if (storage.errorPresent) {
        summary += '${_sentenceFiller('failedQuantifier')} contains ';
      } else {
        summary += '${_sentenceFiller('compiledQuantifier')} contains ';
      }
      summary += '${_sentenceFiller('errorCount', storage.errorCount)} ';
      summary += 'errors and warnings';
      summary += '${_featureList(_codeSearch())}';
      summary += '${_htmlCSS()}';
      summary += '${_packageList(storage.packageImports, source: 'packages')}';
      summary += '${_additionList(_additionSearch())}';
      return summary.trim();
    } else {
      var summary = 'Summary: ';
      summary += 'This is a ${_sentenceFiller('size', storage.linesCode)} ';
      summary += '${_sentenceFiller('compiledQuantifier')}';
      summary += '${_featureList(_codeSearch())}';
      summary += '${_htmlCSS()}';
      summary += '${_additionList(_additionSearch())}';
      return summary.trim();
    }
  }

  String returnAsMarkDown() {
    // For now, we're just returning plain text. This might change at some point
    // to include some markdown styling as well.
    return returnAsSimpleSummary();
  }
}

class _SummarizeToken {
  int linesCode;
  int packageCount;
  int errorCount;
  int warningCount;

  bool errorPresent;
  bool warningPresent;

  List<String> packageImports;

  List<proto.AnalysisIssue> errors;

  _SummarizeToken(String input, {proto.AnalysisResults analysis}) {
    linesCode = _linesOfCode(input);
    if (analysis != null) {
      errorPresent = analysis.issues
          .any((proto.AnalysisIssue issue) => issue.kind == 'error');
      warningPresent = analysis.issues
          .any((proto.AnalysisIssue issue) => issue.kind == 'warning');
      packageCount = analysis.packageImports.length;
      packageImports = analysis.packageImports;
      errors = analysis.issues;
      errorCount = errors.length;
    }
  }

  int _linesOfCode(String input) => input.split('\n').length;
}
