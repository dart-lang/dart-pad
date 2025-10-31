// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A compile-time flag to control making requests over websockets.
///
/// Do not check this in `true`; this will create a long-lived connection to the
/// backend and we don't yet know how well that will scale.
const bool useWebsockets = false;

// todo: test without
