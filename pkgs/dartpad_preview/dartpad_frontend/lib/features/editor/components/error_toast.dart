// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/app_event_bus.dart';
import '../../shared/events/error_toast_event.dart';
import '../../shared/icons.dart';

/// Displays transient error notifications over the top-right of the editor.
final class ErrorToast extends StatefulComponent {
  const ErrorToast({
    required this.events,
    this.displayDuration = const Duration(seconds: 5),
    super.key,
  });

  final AppEventBus events;
  final Duration displayDuration;

  @override
  State<ErrorToast> createState() => _ErrorToastState();

  @css
  static List<StyleRule> get styles => _ErrorToastState.styles;
}

final class _ErrorToastState extends State<ErrorToast> {
  StreamSubscription<ErrorToastEvent>? _subscription;
  Timer? _dismissTimer;
  String? _message;
  int _toastId = 0;

  @override
  void initState() {
    super.initState();
    _subscribe(component.events);
  }

  @override
  void didUpdateComponent(ErrorToast oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(component.events, oldComponent.events)) {
      unawaited(_subscription?.cancel());
      _subscribe(component.events);
    }
  }

  void _subscribe(AppEventBus events) {
    _subscription = events.on<ErrorToastEvent>().listen(_show);
  }

  void _show(ErrorToastEvent event) {
    if (!mounted) {
      return;
    }
    _dismissTimer?.cancel();
    setState(() {
      _message = event.message;
      _toastId++;
    });
    _scheduleDismiss();
  }

  void _scheduleDismiss() {
    _dismissTimer = Timer(component.displayDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = null;
      });
    });
  }

  @override
  Component build(BuildContext context) {
    final message = _message;
    // Keep the stateful component's root render object stable. Replacing an
    // empty component with a keyed element while the context menu closes can
    // otherwise make Jaspr detach the old fragment from the wrong parent.
    return div(classes: 'editor-error-toast-host', [
      if (message != null)
        div(
          key: ValueKey(_toastId),
          classes: 'editor-error-toast',
          attributes: const {
            'role': 'alert',
            'aria-live': 'assertive',
            'aria-atomic': 'true',
          },
          [
            const Icon('error', size: 18, classes: 'editor-error-toast-icon'),
            span([.text(message)]),
          ],
        ),
    ]);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  static List<StyleRule> get styles => [
    css.keyframes('editor-error-toast-lifetime', {
      '0%': Styles(
        opacity: 0,
        transform: .translate(y: (-8).px),
      ),
      '5%': Styles(
        opacity: 1,
        transform: .translate(y: 0.px),
      ),
      '90%': Styles(
        opacity: 1,
        transform: .translate(y: 0.px),
      ),
      '100%': Styles(
        opacity: 0,
        transform: .translate(y: 0.px),
      ),
    }),
    css('.editor-error-toast').styles(
      display: .flex,
      position: .absolute(top: 16.px, right: 16.px),
      zIndex: const ZIndex(20),
      maxWidth: 360.px,
      padding: .symmetric(vertical: 10.px, horizontal: 14.px),
      border: .all(color: colorError, width: 1.px),
      radius: .circular(8.px),
      shadow: BoxShadow(
        offsetX: 0.px,
        offsetY: 4.px,
        blur: 12.px,
        color: Colors.black.withOpacity(0.25),
      ),
      pointerEvents: .none,
      animation: Animation(
        name: 'editor-error-toast-lifetime',
        duration: 5.seconds,
        curve: .easeInOut,
        fillMode: .forwards,
      ),
      alignItems: .center,
      gap: .all(8.px),
      color: colorOnContainer,
      fontSize: 14.px,
      fontWeight: .w500,
      backgroundColor: colorErrorSurface,
    ),
    css('.editor-error-toast-icon').styles(
      color: colorError,
    ),
  ];
}
