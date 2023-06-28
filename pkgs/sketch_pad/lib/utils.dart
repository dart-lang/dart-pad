// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttering_phrases/fluttering_phrases.dart'
    as fluttering_phrases;

import 'theme.dart';

const defaultSnippetSource = r'''
void main() {
  for (int i = 0; i < 5; i++) {
    print('hello ${i + 1}');
  }
}
''';

String pluralize(String word, int count) {
  return count == 1 ? word : '${word}s';
}

void unimplemented(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Unimplemented: $message')),
  );
}

String generateSnippetName() => fluttering_phrases.generate();

Image dartLogo({double? width}) {
  return Image.asset('assets/dart_logo_128.png',
      width: width ?? defaultIconSize);
}

Image flutterLogo({double? width}) {
  return Image.asset('assets/flutter_logo_192.png',
      width: width ?? defaultIconSize);
}

/// Support a stack of progress and status messages.
///
/// Fires a notification when the top-most status changes.
class ProgressController {
  final List<Message> messages = [];

  void showToast(
    String toastMessage, {
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final message = Message._(this, toastMessage);
    messages.add(message);

    // Create in a 'opening' state.
    _recalcProgressState();

    // Transition to a 'showing' state.
    Timer(animationDelay, () {
      _updateMessageState(message, MessageState.showing);
    });

    // Finally, start the 'closing' animation.
    Timer(duration, () => message.close());
  }

  Message showMessage({required String initialText, String? name}) {
    final message = Message._(this, initialText, name: name);
    messages.add(message);
    _recalcProgressState();
    return message;
  }

  final ValueNotifier<MessageStatus> _state =
      ValueNotifier(MessageStatus.empty);

  ValueListenable<MessageStatus> get state => _state;

  Message? getNamedMessage(String name) {
    return messages.firstWhereOrNull((message) {
      return message.name == name && message.state != MessageState.closing;
    });
  }

  void _recalcProgressState() {
    if (messages.isEmpty) {
      _state.value = MessageStatus.empty;
    } else {
      final value = messages.last;
      _state.value = MessageStatus(message: value.message, state: value.state);
    }
  }

  void _close(Message message) {
    _updateMessageState(message, MessageState.closing);

    Timer(animationDelay, () {
      messages.remove(message);
      _recalcProgressState();
    });
  }

  void _updateMessageState(Message message, MessageState state) {
    message._state = state;
    _recalcProgressState();
  }
}

class Message {
  final ProgressController _parent;
  final String? name;

  String _message;
  MessageState _state = MessageState.opening;

  Message._(ProgressController parent, String message, {this.name})
      : _parent = parent,
        _message = message;

  MessageState get state => _state;

  String get message => _message;

  void updateText(String newMessage) {
    _message = newMessage;
    _parent._recalcProgressState();
  }

  void close() => _parent._close(this);
}

class MessageStatus {
  // todo: or, state 'closed'?
  static final MessageStatus empty =
      MessageStatus(message: '', state: MessageState.closing);

  final String message;
  final MessageState state;

  MessageStatus({required this.message, required this.state});

  @override
  bool operator ==(Object other) {
    if (other is! MessageStatus) return false;
    return message == other.message && state == other.state;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => '[$state] $message';
}

enum MessageState {
  opening,
  showing,
  closing,
  ;
}
