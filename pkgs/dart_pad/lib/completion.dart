// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart' as ds;

import 'editing/editor.dart';

// TODO: For CodeMirror, we get a request each time the user hits a key when the
// completion popup is open. We need to cache the results when appropriate.

class DartCompleter extends CodeCompleter {
  final ds.ServicesClient servicesApi;
  final Document document;

  DartCompleter(this.servicesApi, this.document);

  @override
  Future<CompletionResult> complete(
    Editor editor, {
    bool onlyShowFixes = false,
  }) async {
    final offset = editor.document.indexFromPos(editor.document.cursor);
    final request = ds.SourceRequest(
      source: editor.document.value,
      offset: offset,
    );

    if (onlyShowFixes) {
      final response = await servicesApi.fixes(request);
      final completions = <Completion>[];

      for (final sourceChange in response.fixes) {
        final fixes = sourceChange.edits.map((edit) {
          return SourceEdit(edit.length, edit.offset, edit.replacement);
        }).toList();

        completions.add(Completion(
          '',
          displayString: sourceChange.message,
          type: 'type-quick_fix',
          quickFixes: fixes,
        ));
      }

      for (final assist in response.assists) {
        final sourceEdits = assist.edits
            .map((edit) =>
                SourceEdit(edit.length, edit.offset, edit.replacement))
            .toList();

        int? absoluteCursorPosition;

        // TODO(redbrogdon): Find a way to properly use these linked edit
        // groups via selections and multiple cursors.
        if (assist.linkedEditGroups.isNotEmpty) {
          absoluteCursorPosition = assist.linkedEditGroups.first.offsets.first;
        }

        // If a specific offset is provided, prefer it to the one calculated
        // from the linked edit groups.
        if (assist.selectionOffset != null) {
          absoluteCursorPosition = assist.selectionOffset;
        }

        final completion = Completion(
          '',
          displayString: assist.message,
          type: 'type-quick_fix',
          quickFixes: sourceEdits,
          absoluteCursorPosition: absoluteCursorPosition,
        );

        completions.add(completion);
      }

      return CompletionResult(
        completions,
        replaceOffset: offset,
        replaceLength: 0,
      );
    } else {
      final response = await servicesApi.complete(request);
      final replaceOffset = response.replacementOffset;
      final replaceLength = response.replacementLength;

      final responses = response.suggestions.map((suggestion) {
        return AnalysisCompletion(replaceOffset, replaceLength, suggestion);
      });

      final completions = responses.map((completion) {
        var displayString = completion.isMethod
            ? '${completion.text}${completion.parameters}'
            : completion.text;
        if (completion.isMethod && completion.returnType != null) {
          displayString += ' → ${completion.returnType}';
        }

        var text = completion.text;

        if (completion.isMethod) {
          text += '()';
        }

        if (completion.isConstructor) {
          displayString += '()';
        }

        final deprecatedClass = completion.isDeprecated ? ' deprecated' : '';

        int? cursorPos;

        if (completion.isMethod && completion.parameterCount! > 0) {
          cursorPos = text.indexOf('(') + 1;
        }

        if (completion.selectionOffset != 0) {
          cursorPos = completion.selectionOffset;
        }

        return Completion(
          text,
          displayString: displayString,
          type: 'type-${completion.type.toLowerCase()}$deprecatedClass',
          cursorOffset: cursorPos,
        );
      }).toList();

      // Removes duplicates when a completion is both a getter and a setter.
      for (final completion in completions) {
        for (final other in completions) {
          if (completion.isSetterAndMatchesGetter(other)) {
            completions.removeWhere((c) => completion == c);
            other.type = 'type-getter_and_setter';
          }
        }
      }

      return CompletionResult(
        completions,
        replaceOffset: replaceOffset,
        replaceLength: replaceLength,
      );
    }
  }
}

class AnalysisCompletion implements Comparable<AnalysisCompletion> {
  final int offset;
  final int length;
  final ds.CompletionSuggestion suggestion;

  AnalysisCompletion(this.offset, this.length, this.suggestion);

  // KEYWORD, INVOCATION, ...
  String get kind => suggestion.kind;

  bool get isMethod =>
      suggestion.elementKind == 'FUNCTION' ||
      suggestion.elementKind == 'METHOD';

  bool get isConstructor => type == 'CONSTRUCTOR';

  String? get parameters => isMethod ? suggestion.elementParameters : null;

  int? get parameterCount =>
      isMethod ? suggestion.parameterNames?.length : null;

  String get text {
    final str = suggestion.completion;
    if (str.startsWith('(') && str.endsWith(')')) {
      return str.substring(1, str.length - 1);
    } else {
      return str;
    }
  }

  String? get returnType => suggestion.returnType;

  bool get isDeprecated => suggestion.deprecated;

  int get selectionOffset => suggestion.selectionOffset;

  // FUNCTION, GETTER, CLASS, ...
  String get type => suggestion.elementKind ?? kind;

  @override
  int compareTo(AnalysisCompletion other) {
    return text.compareTo(other.text);
  }

  @override
  String toString() => text;
}
