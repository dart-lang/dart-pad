import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../shared/icons.dart';

/// A stateful item representing a text input for creating/renaming.
class FileTreeInputItem extends StatefulComponent {
  const FileTreeInputItem({
    required this.depth,
    required this.icon,
    this.placeholder,
    required this.onConfirm,
    required this.onCancel,
    this.initialValue,
    this.confirmOnBlur = false,
    this.checkConflict,
    super.key,
  });

  final int depth;
  final Component icon;
  final String? placeholder;
  final String? initialValue;
  final bool confirmOnBlur;
  final void Function(String value) onConfirm;
  final void Function() onCancel;
  final String? Function(String value)? checkConflict;

  @override
  State<FileTreeInputItem> createState() => _FileTreeInputItemState();
}

class _FileTreeInputItemState extends State<FileTreeInputItem> {
  static int _counter = 0;
  late final String inputId;
  late String value;
  bool _disposed = false;
  bool _userHasEdited = false;

  @override
  void initState() {
    super.initState();
    inputId = 'file-tree-input-${_counter++}';
    value = component.initialValue ?? '';

    scheduleMicrotask(() {
      Timer.run(() {
        if (!_disposed && mounted) {
          final input = web.document.getElementById(inputId) as web.HTMLInputElement?;
          input
            ?..focus()
            ..select();
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
    final hasError = validationError != null;
    final displayError = _userHasEdited ? validationError : null;

    return div(
      classes: 'file-tree-input-wrapper',
      styles: Styles(raw: {'--tree-depth': '${component.depth}'}),
      [
        div(classes: 'file-tree-item input-row', [
          const span(classes: 'file-tree-disclosure spacer', []),
          component.icon,
          input<String>(
            id: inputId,
            classes: 'file-tree-input${displayError != null ? ' invalid' : ''}',
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
                  Timer(const Duration(milliseconds: 150), () {
                    if (_disposed || !mounted) {
                      return;
                    }
                    final trimmed = value.trim();
                    if (trimmed.isEmpty) {
                      component.onCancel();
                    } else if (validationError == null) {
                      component.onConfirm(trimmed);
                    } else {
                      component.onCancel();
                    }
                  });
                }
              },
              'keydown': (event) {
                final keyboardEvent = event as web.KeyboardEvent;
                if (keyboardEvent.key == 'Enter' && !hasError) {
                  component.onConfirm(value.trim());
                } else if (keyboardEvent.key == 'Escape') {
                  component.onCancel();
                }
              },
            },
          ),
          button(
            classes: 'file-tree-action confirm',
            attributes: {
              'title': 'Confirm',
              if (hasError) 'disabled': '',
            },
            onClick: hasError ? null : () => component.onConfirm(value.trim()),
            [const Icon('check', size: 12)],
          ),
          button(
            classes: 'file-tree-action delete',
            attributes: {'title': 'Cancel'},
            onClick: component.onCancel,
            [const Icon('close', size: 12)],
          ),
        ]),
        if (displayError case final error?) div(classes: 'file-tree-validation', [.text(error)]),
      ],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
