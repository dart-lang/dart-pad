// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.completion;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:logging/logging.dart';

import 'dartservices_client/v1.dart';
import 'editing/editor.dart';
import 'src/util.dart';

Logger _logger = new Logger('completion');

// TODO: For CodeMirror, we get a request each time the user hits a key when the
// completion popup is open. We need to cache the results when appropriate.

class DartCompleter extends CodeCompleter {
  final DartservicesApi servicesApi;
  final Document document;

  CancellableCompleter _lastCompleter;

  DartCompleter(this.servicesApi, this.document);

  Future<List<Completion>> complete(Editor editor) {
    // Cancel any open completion request.
    if (_lastCompleter != null) _lastCompleter.cancel(reason: "new request");

    int offset = editor.document.indexFromPos(editor.document.cursor);

    var request = new SourceRequest()
      ..source = editor.document.value
      ..offset = offset;

    Stopwatch timer = new Stopwatch()..start();

    CancellableCompleter completer = new CancellableCompleter();
    _lastCompleter = completer;

    servicesApi.complete(request).then((CompleteResponse response) {
      if (completer.isCancelled) return;

      _logger.info('completion request in ${timer.elapsedMilliseconds}ms; '
          '${response.completions.length} completions, '
          'offset=${response.replacementOffset}, '
          'length=${response.replacementLength}');

      List<AnalysisCompletion> analysisCompletions = response.completions.map(
          (completion) {
        return new AnalysisCompletion(
            response.replacementOffset, response.replacementLength, completion);
      }).toList();

      int replacementOffset = response.replacementOffset;
      int delta = offset - replacementOffset;
      String lowerPrefix = editor.document.value.substring(
          replacementOffset, replacementOffset + delta).toLowerCase();


      List<Completion> completions =  analysisCompletions.map((completion) {
        // TODO: Move to using a LabelProvider; decouple the data and rendering.
        String displayString = (completion.isMethod || completion.type == "METHOD") ? '${completion.text}()' : completion.text;
        if ((completion.isMethod || completion.type == "METHOD") && completion.returnType != null) {
          displayString += ' → ${completion.returnType}';
        }

        // Filter unmatching completions.
        if (delta > 0) {
          if (!completion.text.toLowerCase().startsWith(lowerPrefix)) {
            return null;
          }
        }

        // TODO: We need to be more precise about the text we're inserting and
        // replacing.
        String text = completion.text;
        if (delta > 0 && delta <= text.length) {
          text = text.substring(delta);
        }
        // TODO: Use classes to decorate the completion UI ('cm-builtin').
        return new Completion(text, displayString: displayString, type: "type-"+completion.type.toLowerCase());
      }).where((x) => x != null).toList();

      completer.complete(completions);
    }).catchError((e) {
      completer.completeError(e);
    });

    return completer.future;
  }
}

//{kind: KEYWORD, relevance: 2000, completion: library, selectionOffset: 7, selectionLength: 0, isDeprecated: false, isPotential: false}
//{kind: INVOCATION, relevance: 1000, completion: int, selectionOffset: 3, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: CLASS, name: int, flags: 1}}
//{kind: INVOCATION, relevance: 1059, completion: i, selectionOffset: 1, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: LOCAL_VARIABLE, name: i, flags: 0, returnType: int}, returnType: int}
//{kind: INVOCATION, relevance: 1056, completion: main, selectionOffset: 4, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: FUNCTION, name: main, flags: 0, parameters: (), returnType: void}, returnType: void, parameterNames: [], parameterTypes: [], requiredParameterCount: 0, hasNamedParameters: false}
//{kind: INVOCATION, relevance: 1000, completion: proxy, selectionOffset: 5, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: GETTER, name: proxy, flags: 8, returnType: Object}, returnType: Object}
//{kind: INVOCATION, relevance: 1000, completion: int, selectionOffset: 3, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: CLASS, name: int, flags: 1}}
//{kind: INVOCATION, relevance: 1000, completion: Cat, selectionOffset: 3, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: CLASS, name: Cat, flags: 0}}
//{kind: INVOCATION, relevance: 1000, completion: print, selectionOffset: 5, selectionLength: 0, isDeprecated: false, isPotential: false, element: {kind: FUNCTION, name: print, flags: 8, parameters: (Object object), returnType: void}, returnType: void, parameterNames: [object], parameterTypes: [Object], requiredParameterCount: 1, hasNamedParameters: false}

class AnalysisCompletion implements Comparable {
  final int offset;
  final int length;

  final Map _map;

  AnalysisCompletion(this.offset, this.length, this._map) {
    // TODO: We need to pass this completion info better.
    _convert('element');
    _convert('parameterNames');
    _convert('parameterTypes');

    if (_map.containsKey('element')) _map['element'].remove('location');
  }

  // Convert maps and lists that have been passed as json.
  void _convert(String key) {
    if (_map[key] is String) _map[key] = JSON.decode(_map[key]);
  }

  // KEYWORD, INVOCATION, ...
  String get kind => _map['kind'];

  bool get isMethod {
    var element = _map['element'];
    return element is Map ? element['kind'] == 'FUNCTION' : false;
  }

  String get text => _map['completion'];

  String get returnType => _map['returnType'];

  int get relevance => _int(_map['relevance']);

  bool get isDeprecated => _map['isDeprecated'] == 'true';

  bool get isPotential => _map['isPotential'] == 'true';

  int get selectionLength => _int(_map['selectionLength']);

  int get selectionOffset => _int(_map['selectionOffset']);

  // FUNCTION, GETTER, CLASS, ...
  String get type => _map['element']['kind'];


  int compareTo(other) {
    if (other is! AnalysisCompletion) return -1;
    return text.compareTo(other.text);
  }

  String toString() => text;

  int _int(String val) => val == null ? 0 : int.parse(val);
}