// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO: have the front-end reconnect as necessary

// TODO: remove the non-websocket REST API?

// TODO: have backend services allocated per-websocket client

/// A compile-time flag to control making requests over websockets.
///
/// Do not check this in `true`; this will create a long-lived connection to the
/// backend and we don't yet know how well that will scale.
const bool useWebsockets = true;
