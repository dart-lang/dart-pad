// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../model.dart';

import '_stub.dart' if (dart.library.js_interop) '_web.dart';

/// Listen to frame messages if embedded as an iFrame
/// to accept injected snippets.
void handleEmbedMessage(AppServices services, {bool runOnInject = false}) =>
    handleEmbedMessageImpl(services, runOnInject: runOnInject);
