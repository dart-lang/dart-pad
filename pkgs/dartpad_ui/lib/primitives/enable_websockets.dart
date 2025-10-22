// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// todo: front-end switched over

// todo: front-end reconnects as necessary

// todo: change call timeout (60 mins)

// todo: backend supports all calls over websocket

// todo: remove non-websocket REST api?

// todo: new backend services spun up per-websocket

// hmm, we're now serving websocket clients and precompiled resources from
// the same backends. do we want specialized backends?

// ---

// todo: change cloud run sizing; num simultaneous connections

/// A compile-time flag to control making requests over websockets.
///
/// Do not check this in `true`; this will create a long-lived connection to the
/// backend and we don't yet know how well that will scale.
const bool useWebsockets = false;
