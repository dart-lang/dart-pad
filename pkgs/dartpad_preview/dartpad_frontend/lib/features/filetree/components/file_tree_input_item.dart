// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../file_tree_models.dart';
import 'file_tree_row.dart';

/// A stateful item representing a text input for creating/renaming.
class FileTreeInputItem extends StatefulComponent {
  const FileTreeInputItem({
    required this.depth,
    required this.icon,
    this.placeholder,
    required this.onConfirm,
    required this.onCancel,
    this.initialValue,
    this.confirmOnBlur = true,
    this.checkConflict,
    this.creationTarget,
    this.creationKind,
    this.active = true,
    super.key,
  });

  /// The depth of this item in the file tree, used to determine indentation.
  final int depth;

  /// The icon component to display next to the input.
  final Component icon;

  /// The optional placeholder text for the text input.
  final String? placeholder;

  /// The initial value of the input, if any.
  final String? initialValue;

  /// Whether to confirm the input value when focus is lost (on blur).
  final bool confirmOnBlur;

  /// Callback when the input is confirmed with a valid value.
  final void Function(String value) onConfirm;

  /// Callback when the input is cancelled.
  final void Function() onCancel;

  /// Optional validation callback to check for conflicts (e.g. name already exists).
  final String? Function(String value)? checkConflict;

  /// The folder for a creation input that can be prepared before it is shown.
  final String? creationTarget;

  /// The entry kind represented by a prepared input, if it is kind-specific.
  final FileTreeEntryKind? creationKind;

  /// Whether a prepared creation input is currently visible.
  final bool active;

  /// Reveals and focuses a prepared creation input during the user gesture.
  ///
  /// iOS WebKit requires this synchronous focus to open the on-screen keyboard.
  static void focusPreparedCreation(
    web.HTMLElement? tree, {
    required String folderPath,
    required FileTreeEntryKind kind,
  }) {
    final rows = tree?.querySelectorAll('[data-create-target]');
    if (rows == null) {
      return;
    }
    for (var i = 0; i < rows.length; i++) {
      final row = rows.item(i) as web.HTMLElement;
      final inputKind = row.getAttribute('data-create-kind');
      if (row.getAttribute('data-create-target') == folderPath && (inputKind == null || inputKind == kind.name)) {
        row.removeAttribute('hidden');
        final input = row.querySelector('input') as web.HTMLInputElement?;
        input?.focus(web.FocusOptions(preventScroll: true));
        return;
      }
    }
  }

  @override
  State<FileTreeInputItem> createState() => _FileTreeInputItemState();
}

class _FileTreeInputItemState extends State<FileTreeInputItem> {
  static int _counter = 0;
  late final String inputId;
  late String value;
  bool _disposed = false;
  bool _userHasEdited = false;
  bool _showError = false;
  bool _completed = false;
  int _activation = 0;

  @override
  void initState() {
    super.initState();
    inputId = 'file-tree-input-${_counter++}';
    value = component.initialValue ?? '';

    if (component.active) {
      _focusAfterRender();
    }
  }

  @override
  void didUpdateComponent(FileTreeInputItem oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.active != oldComponent.active) {
      _activation++;
      if (component.active) {
        _completed = false;
        _focusAfterRender();
      } else {
        value = component.initialValue ?? '';
        _userHasEdited = false;
        _showError = false;
        _completed = true;
      }
    }
  }

  void _focusAfterRender() {
    scheduleMicrotask(() {
      Timer.run(() {
        if (!_disposed && mounted && component.active) {
          final input = web.document.getElementById(inputId) as web.HTMLInputElement?;
          if (input != null && web.document.activeElement != input) {
            input
              ..focus()
              ..select();
          }
        }
      });
    });
  }

  String? get validationError {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'A name is required.';
    }
    if (value != trimmed) {
      return 'Leading or trailing whitespace is not allowed.';
    }
    if (value == '.' || value == '..') {
      return '"$value" is not a valid workspace name.';
    }
    final invalidCharacters = RegExp(r'[\x00-\x1f\x7f/\\]');
    if (invalidCharacters.hasMatch(value)) {
      return 'The name contains a path separator or control character.';
    }
    if (component.checkConflict?.call(trimmed) case final conflictError?) {
      return conflictError;
    }
    return null;
  }

  @override
  Component build(BuildContext context) {
    final displayError = (_userHasEdited || _showError) ? validationError : null;

    return FileTreeRow(
      depth: component.depth,
      classes: 'file-tree-input-wrapper',
      attributes: {
        'data-create-target': ?component.creationTarget,
        'data-create-kind': ?component.creationKind?.name,
        if (!component.active) 'hidden': '',
      },
      children: [
        div(classes: 'file-tree-item input-row', [
          const span(classes: 'file-tree-disclosure spacer', []),
          component.icon,
          div(classes: 'file-tree-input-container', [
            input<String>(
              id: inputId,
              classes: component.active
                  ? 'file-tree-input${displayError != null ? ' invalid' : ''}'
                  : 'file-tree-input-prepared',
              value: value,
              attributes: {
                'type': 'text',
                'placeholder': ?component.placeholder,
                'spellcheck': 'false',
                'autocomplete': 'off',
              },
              onInput: (val) {
                setState(() {
                  value = val;
                  _userHasEdited = true;
                });
              },
              events: {
                'blur': (_) {
                  if (component.confirmOnBlur) {
                    final activation = _activation;
                    Timer(const Duration(milliseconds: 150), () {
                      if (_completed || _disposed || !mounted || activation != _activation) {
                        return;
                      }
                      final trimmed = value.trim();
                      if (trimmed.isEmpty) {
                        _completed = true;
                        component.onCancel();
                      } else if (validationError == null) {
                        _completed = true;
                        component.onConfirm(trimmed);
                      } else {
                        _completed = true;
                        component.onCancel();
                      }
                    });
                  }
                },
                'keydown': (event) {
                  final keyboardEvent = event as web.KeyboardEvent;
                  if (keyboardEvent.key == 'Enter') {
                    keyboardEvent.preventDefault();
                    if (validationError == null) {
                      _completed = true;
                      component.onConfirm(value.trim());
                    } else {
                      setState(() {
                        _showError = true;
                      });
                    }
                  } else if (keyboardEvent.key == 'Escape') {
                    keyboardEvent.preventDefault();
                    _completed = true;
                    component.onCancel();
                  }
                },
              },
            ),
            if (displayError case final error?) div(classes: 'file-tree-validation', [.text(error)]),
          ]),
        ]),
      ],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
