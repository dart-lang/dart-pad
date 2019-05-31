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

  @override
  Future<CompletionResult> complete(
    Editor editor, {
    bool onlyShowFixes = false,
  }) {
    // Cancel any open completion request.
    if (_lastCompleter != null) _lastCompleter.cancel();

    int offset = editor.document.indexFromPos(editor.document.cursor);

    var request = SourceRequest()
      ..source = editor.document.value
      ..offset = offset;

    CancellableCompleter<CompletionResult> completer =
        CancellableCompleter<CompletionResult>();
    _lastCompleter = completer;

    if (onlyShowFixes) {
      List<Completion> completions = [];
      var fixesFuture =
          servicesApi.fixes(request).then((FixesResponse response) {
        for (ProblemAndFixes problemFix in response.fixes) {
          for (CandidateFix fix in problemFix.fixes) {
            List<SourceEdit> fixes = fix.edits.map((edit) {
              return SourceEdit(edit.length, edit.offset, edit.replacement);
            }).toList();

            completions.add(Completion(
              '',
              displayString: fix.message,
              type: 'type-quick_fix',
              quickFixes: fixes,
            ));
          }
        }
      });
      var assistsFuture =
          servicesApi.assists(request).then((AssistsResponse response) {
        for (var assist in response.assists) {
          var sourceEdits = assist.edits
              .map((edit) =>
                  SourceEdit(edit.length, edit.offset, edit.replacement))
              .toList();

          var completion = Completion(
            '',
            displayString: assist.message,
            type: 'type-quick_fix',
            quickFixes: sourceEdits,
          );

          completions.add(completion);
        }
      });

      Future.wait([fixesFuture, assistsFuture]).then((_) {
        completer.complete(CompletionResult(completions,
            replaceOffset: offset, replaceLength: 0));
      });
    } else {
      servicesApi.complete(request).then((CompleteResponse response) {
        if (completer.isCancelled) return;

        int replaceOffset = response.replacementOffset;
        int replaceLength = response.replacementLength;

        Iterable<AnalysisCompletion> responses =
            response.completions.map((Map completion) {
          return AnalysisCompletion(replaceOffset, replaceLength, completion);
        });

        List<Completion> completions = responses.map((completion) {
          // TODO: Move to using a LabelProvider; decouple the data and rendering.
          String displayString = completion.isMethod
              ? '${completion.text}${completion.parameters}'
              : completion.text;
          if (completion.isMethod && completion.returnType != null) {
            displayString += ' → ${completion.returnType}';
          }

          String text = completion.text;

          if (completion.isMethod) {
            text += '()';
          }

          if (completion.isConstructor) {
            displayString += '()';
          }

          String deprecatedClass = completion.isDeprecated ? ' deprecated' : '';

          if (completion.type == null) {
            return Completion(
              text,
              displayString: displayString,
              type: deprecatedClass,
            );
          } else {
            int cursorPos;

            if (completion.isMethod && completion.parameterCount > 0) {
              cursorPos = text.indexOf('(') + 1;
            }

            return Completion(
              text,
              displayString: displayString,
              type: 'type-${completion.type.toLowerCase()}$deprecatedClass',
              cursorOffset: cursorPos,
            );
          }
        }).toList();

        // Removes duplicates when a completion is both a getter and a setter.
        for (Completion completion in completions) {
          for (Completion other in completions) {
            if (completion.isSetterAndMatchesGetter(other)) {
              completions.removeWhere((c) => completion == c);
              other.type = 'type-getter_and_setter';
            }
          }
        }

        completer.complete(CompletionResult(
          completions,
          replaceOffset: replaceOffset,
          replaceLength: replaceLength,
        ));
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
    _map = Map<String, dynamic>.from(map);

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

  bool get isConstructor => type == 'CONSTRUCTOR';

  String get parameters => isMethod ? _map['element']['parameters'] : null;

  int get parameterCount => isMethod ? _map['parameterNames'].length : null;

  String get text {
    String str = _map['completion'];
    if (str.startsWith('(') && str.endsWith(')')) {
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

  @override
  int compareTo(other) {
    if (other is! AnalysisCompletion) return -1;
    return text.compareTo(other.text);
  }

  @override
  String toString() => text;

  int _int(String val) => val == null ? 0 : int.parse(val);
}
