// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Only worker ownership is under test. Reject workspace requests instead of
// loading SDK assets, while exercising the real DartPad client and shutdown.
export class Worker {
  static async create() {
    return new Worker();
  }

  session(port) {
    port.onmessage = ({ data }) => {
      const request = JSON.parse(data.payload);
      port.postMessage({
        payload: JSON.stringify({
          jsonrpc: '2.0',
          id: request.id,
          error: { code: -32603, message: 'Test worker unavailable' },
        }),
      });
    };
  }
}
