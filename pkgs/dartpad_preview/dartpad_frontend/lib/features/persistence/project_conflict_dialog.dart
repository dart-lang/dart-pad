// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../app_styles.dart';

/// A friendly, non-dismissible choice. Native modality traps focus and makes
/// the rest of the document inert, including editors and preview iframes.
final class ProjectConflictDialog extends StatefulComponent {
  const ProjectConflictDialog({required this.onUseLatest, required this.onKeepVersion, this.busy = false, super.key});

  final VoidCallback onUseLatest;
  final VoidCallback onKeepVersion;
  final bool busy;

  @override
  State<ProjectConflictDialog> createState() => _ProjectConflictDialogState();

  @css
  static List<StyleRule> get styles => _ProjectConflictDialogState.styles;
}

final class _ProjectConflictDialogState extends State<ProjectConflictDialog> {
  web.HTMLDialogElement? _element;
  late final JSFunction _keyDown = ((web.KeyboardEvent event) {
    if (event.key == 'Escape') {
      event.preventDefault();
    } else if (event.key == 'Tab' && component.busy) {
      event.preventDefault();
    } else if (event.key == 'Tab') {
      final buttons = _element!.querySelectorAll('button');
      final first = buttons.item(0)! as web.HTMLElement;
      final last = buttons.item(buttons.length - 1)! as web.HTMLElement;
      if (event.shiftKey && web.document.activeElement == first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && web.document.activeElement == last) {
        event.preventDefault();
        first.focus();
      }
    } else if ((event.metaKey || event.ctrlKey) && event.key == 'Enter') {
      event.preventDefault();
    }
    event.stopPropagation();
  }).toJS;

  @override
  void initState() {
    super.initState();
    context.binding.addPostFrameCallback(() {
      if (!mounted) {
        return;
      }
      final element = web.document.querySelector('#project-conflict-dialog') as web.HTMLDialogElement?;
      if (element != null && !element.open) {
        _element = element;
        // The native cancel event does not bubble, so Jaspr's delegated event
        // handlers cannot prevent Escape from closing a modal dialog.
        element.oncancel = ((web.Event event) => event.preventDefault()).toJS;
        element.addEventListener('keydown', _keyDown);
        element.showModal();
      }
    });
  }

  @override
  void didUpdateComponent(ProjectConflictDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.busy == oldComponent.busy) {
      return;
    }
    context.binding.addPostFrameCallback(() {
      if (!mounted) {
        return;
      }
      final selector = component.busy ? '#project-conflict-title' : '[autofocus]';
      (_element?.querySelector(selector) as web.HTMLElement?)?.focus();
    });
  }

  @override
  void dispose() {
    _element?.removeEventListener('keydown', _keyDown);
    _element?.oncancel = null;
    _element?.close();
    super.dispose();
  }

  @override
  Component build(BuildContext context) => dialog(
    id: 'project-conflict-dialog',
    classes: 'project-conflict-dialog',
    attributes: {
      'aria-labelledby': 'project-conflict-title',
      'aria-describedby': 'project-conflict-description',
      'aria-modal': 'true',
      if (component.busy) 'aria-busy': 'true',
    },
    [
      const h2(
        id: 'project-conflict-title',
        attributes: {'tabindex': '-1'},
        [.text('This project is open in another tab.')],
      ),
      const p(id: 'project-conflict-description', [
        .text(
          'Another tab is now using this project. Keep your version as a separate project, or load the latest version.',
        ),
      ]),
      div(classes: 'project-conflict-actions', [
        button(
          classes: 'project-conflict-primary',
          disabled: component.busy,
          onClick: component.onUseLatest,
          const [.text('Use latest version')],
        ),
        button(
          attributes: const {'autofocus': ''},
          disabled: component.busy,
          onClick: component.onKeepVersion,
          const [.text('Keep my version')],
        ),
      ]),
    ],
  );

  static List<StyleRule> get styles => [
    css('.project-conflict-dialog').styles(
      width: 440.px,
      maxWidth: 90.vw,
      padding: .all(28.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(12.px),
      color: colorOnSurface,
      backgroundColor: colorContainer,
    ),
    css('.project-conflict-dialog::backdrop').styles(backgroundColor: const Color('rgba(0, 0, 0, 0.25)')),
    css('.project-conflict-dialog h2').styles(margin: .zero, color: colorOnContainer, fontSize: 22.px),
    css('.project-conflict-dialog p').styles(lineHeight: 1.6.em),
    css('.project-conflict-actions').styles(display: .flex, flexWrap: .wrap, gap: Gap.all(12.px)),
    css('.project-conflict-actions button').styles(
      padding: .symmetric(vertical: 10.px, horizontal: 16.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(6.px),
      cursor: .pointer,
      color: colorOnContainer,
      fontSize: 14.px,
      backgroundColor: colorContainer,
    ),
    css('.project-conflict-actions .project-conflict-primary').styles(
      border: .all(color: colorPrimary, width: 1.px),
      color: colorOnPrimary,
      backgroundColor: colorPrimary,
    ),
  ];
}
