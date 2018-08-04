// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.completion;

import 'dart:async';
import 'dart:convert' show jsonDecode;

import 'editing/editor.dart';
import 'services/dartservices.dart' hide SourceEdit;
import 'src/util.dart';

// TODO: For CodeMirror, we get a request each time the user hits a key when the
// completion popup is open. We need to cache the results when appropriate.

class DartCompleter extends CodeCompleter {
  final DartservicesApi servicesApi;
  final Document document;

  CancellableCompleter _lastCompleter;

  DartCompleter(this.servicesApi, this.document);

  Future<CompletionResult> complete(Editor editor,
      {bool onlyShowFixes: false}) {
    // Cancel any open completion request.
    if (_lastCompleter != null) _lastCompleter.cancel(reason: "new request");

    int offset = editor.document.indexFromPos(editor.document.cursor);

    var request = new SourceRequest()
      ..source = editor.document.value
      ..offset = offset;

    CancellableCompleter<CompletionResult> completer =
        new CancellableCompleter<CompletionResult>();
    _lastCompleter = completer;

    if (onlyShowFixes) {
      servicesApi.fixes(request).then((FixesResponse response) {
        List<Completion> completions = [];
        for (ProblemAndFixes problemFix in response.fixes) {
          for (CandidateFix fix in problemFix.fixes) {
            List<SourceEdit> fixes = fix.edits.map((edit) {
              return new SourceEdit(edit.length, edit.offset, edit.replacement);
            }).toList();

            completions.add(new Completion("",
                displayString: fix.message,
                type: "type-quick_fix",
                quickFixes: fixes));
          }
        }
        completer.complete(new CompletionResult(completions,
            replaceOffset: offset, replaceLength: 0));
      });
    } else {
      servicesApi.complete(request).then((CompleteResponse response) {
        if (completer.isCancelled) return;

        int replaceOffset = response.replacementOffset;
        int replaceLength = response.replacementLength;

        String replacementString = editor.document.value
            .substring(replaceOffset, replaceOffset + replaceLength);

        List<AnalysisCompletion> analysisCompletions =
            response.completions.map((Map completion) {
          return new AnalysisCompletion(
              replaceOffset, replaceLength, completion);
        }).toList();

        List<Completion> completions = analysisCompletions
            .map((completion) {
              // TODO: Move to using a LabelProvider; decouple the data and rendering.
              String displayString = completion.isMethod
                  ? '${completion.text}${completion.parameters}'
                  : completion.text;
              if (completion.isMethod && completion.returnType != null) {
                displayString += ' → ${completion.returnType}';
              }

              // Filter unmatching completions.
              // TODO: This is temporary; tracking issue here:
              // https://github.com/dart-lang/dart-services/issues/87.
              if (replacementString.isNotEmpty) {
                if (!completion.matchesCompletionFragment(replacementString)) {
                  return null;
                }
              }

              String text = completion.text;

              if (completion.isMethod) text += "()";

              String deprecatedClass =
                  completion.isDeprecated ? ' deprecated' : '';

              if (completion.type == null) {
                return new Completion(text,
                    displayString: displayString, type: deprecatedClass);
              } else {
                int cursorPos = null;

                if (completion.isMethod && completion.parameterCount > 0) {
                  cursorPos = text.indexOf('(') + 1;
                }

                return new Completion(text,
                    displayString: displayString,
                    type:
                        "type-${completion.type.toLowerCase()}${deprecatedClass}",
                    cursorOffset: cursorPos);
              }
            })
            .where((x) => x != null)
            .toList();

        List<Completion> filterCompletions = new List.from(completions);

        // Removes duplicates when a completion is both a getter and a setter.
        for (Completion completion in completions) {
          for (Completion other in completions) {
            if (completion.isSetterAndMatchesGetter(other)) {
              filterCompletions.removeWhere((c) => completion == c);
              other.type = "type-getter_and_setter";
            }
          }
        }

        completer.complete(new CompletionResult(filterCompletions,
            replaceOffset: replaceOffset, replaceLength: replaceLength));
      }).catchError((e) {
        completer.completeError(e);
      });
    }

    return completer.future;
  }
}

class AnalysisCompletion implements Comparable {
  final int offset;
  final int length;

  Map _map;

  AnalysisCompletion(this.offset, this.length, Map<String, dynamic> map) {
    _map = new Map<String, dynamic>.from(map);

    // TODO: We need to pass this completion info better.
    _convert('element');
    _convert('parameterNames');
    _convert('parameterTypes');

    if (_map.containsKey('element')) _map['element'].remove('location');
  }

  // Convert maps and lists that have been passed as json.
  void _convert(String key) {
    if (_map[key] is String) {
      _map[key] = jsonDecode(_map[key]);
    }
  }

  // KEYWORD, INVOCATION, ...
  String get kind => _map['kind'];

  bool get isMethod {
    var element = _map['element'];
    return element is Map
        ? (element['kind'] == 'FUNCTION' || element['kind'] == 'METHOD')
        : false;
  }

  String get parameters => isMethod ? _map['element']["parameters"] : null;

  int get parameterCount => isMethod ? _map['parameterNames'].length : null;

  String get text {
    String str = _map['completion'];
    if (str.startsWith("(") && str.endsWith(")")) {
      return str.substring(1, str.length - 1);
    } else {
      return str;
    }
  }

  String get returnType => _map['returnType'];

  int get relevance => _int(_map['relevance']);

  bool get isDeprecated => _map['isDeprecated'] == 'true';

  bool get isPotential => _map['isPotential'] == 'true';

  int get selectionLength => _int(_map['selectionLength']);

  int get selectionOffset => _int(_map['selectionOffset']);

  // FUNCTION, GETTER, CLASS, ...
  String get type =>
      _map.containsKey('element') ? _map['element']['kind'] : kind;

  bool matchesCompletionFragment(String completionFragment) =>
      text.toLowerCase().startsWith(completionFragment.toLowerCase());

  int compareTo(other) {
    if (other is! AnalysisCompletion) return -1;
    return text.compareTo(other.text);
  }

  String toString() => text;

  int _int(String val) => val == null ? 0 : int.parse(val);
}
