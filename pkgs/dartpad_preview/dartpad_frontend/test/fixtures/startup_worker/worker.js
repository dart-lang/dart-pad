// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Let app preparation finish so tests can observe whether Run is triggered.
// These tests do not need a real analyzer or compiler.
export class Worker {
  static async create() {
    return new Worker();
  }

  session(port) {
    port.onmessage = ({ data }) => {
      const request = JSON.parse(data.payload);
      const result = {
        createWorkspace: { workspaceId: 1, workspaceFolder: 'file:///workspace/' },
        'workspace/pub': { log: '' },
      }[request.method];
      port.postMessage({
        payload: JSON.stringify({
          jsonrpc: '2.0',
          id: request.id,
          ...(result === undefined
            ? { error: { code: -32601, message: 'No analyzer or compiler in this fixture' } }
            : { result }),
        }),
      });
    };
  }
}
