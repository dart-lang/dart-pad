// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

(function () {
  'use strict';

  // Fix DevTools routing: when index.html is loaded directly, rewrite the history path
  // from /devtools/index.html to /devtools/inspector (or the specified page query param).
  try {
    const url = new URL(window.location.href);
    if (url.pathname.endsWith('index.html')) {
      const page = url.searchParams.get('page') || 'inspector';
      url.searchParams.delete('page');

      let basePath = '/devtools/';
      const baseEl = document.querySelector('base');
      if (baseEl && baseEl.getAttribute('href')) {
        basePath = baseEl.getAttribute('href');
        if (!basePath.endsWith('/')) basePath += '/';
      }

      url.pathname = basePath + page.replace(/^\//, '');
      window.history.replaceState(null, '', url.toString());
    }
  } catch (e) {
    console.warn('Failed to rewrite DevTools route URL:', e);
  }

  const OriginalWebSocket = window.WebSocket;

  class MessagePortWebSocket extends EventTarget {
    static get CONNECTING() { return 0; }
    static get OPEN() { return 1; }
    static get CLOSING() { return 2; }
    static get CLOSED() { return 3; }

    get CONNECTING() { return 0; }
    get OPEN() { return 1; }
    get CLOSING() { return 2; }
    get CLOSED() { return 3; }

    constructor(url, protocols) {
      super();
      this._url = (url && url.toString) ? url.toString() : String(url);
      this._protocols = protocols;
      this._protocol = Array.isArray(protocols) ? (protocols[0] || '') : (protocols || '');
      this._extensions = '';
      this._binaryType = 'blob';
      this._bufferedAmount = 0;
      this._readyState = MessagePortWebSocket.CONNECTING;

      this._onopen = null;
      this._onmessage = null;
      this._onerror = null;
      this._onclose = null;

      this._pendingSends = [];
      this._port = window.__devtools_ws_port || null;

      window.__devtools_ws_sockets = window.__devtools_ws_sockets || [];
      window.__devtools_ws_sockets.push(this);

      console.log('[DevTools WS] Created WebSocket for:', this._url);

      if (this._port) {
        this._bindPort(this._port);
      }
    }

    get url() { return this._url; }
    get protocol() { return this._protocol; }
    get extensions() { return this._extensions; }
    get bufferedAmount() { return this._bufferedAmount; }
    get readyState() { return this._readyState; }

    get binaryType() { return this._binaryType; }
    set binaryType(value) { this._binaryType = value; }

    get onopen() { return this._onopen; }
    set onopen(fn) {
      if (this._onopen) {
        this.removeEventListener('open', this._onopen);
      }
      this._onopen = fn;
      if (typeof fn === 'function') {
        this.addEventListener('open', fn);
      }
    }

    get onmessage() { return this._onmessage; }
    set onmessage(fn) {
      if (this._onmessage) {
        this.removeEventListener('message', this._onmessage);
      }
      this._onmessage = fn;
      if (typeof fn === 'function') {
        this.addEventListener('message', fn);
      }
    }

    get onerror() { return this._onerror; }
    set onerror(fn) {
      if (this._onerror) {
        this.removeEventListener('error', this._onerror);
      }
      this._onerror = fn;
      if (typeof fn === 'function') {
        this.addEventListener('error', fn);
      }
    }

    get onclose() { return this._onclose; }
    set onclose(fn) {
      if (this._onclose) {
        this.removeEventListener('close', this._onclose);
      }
      this._onclose = fn;
      if (typeof fn === 'function') {
        this.addEventListener('close', fn);
      }
    }

    _bindPort(port) {
      if (!port) return;
      this._port = port;
      console.log('[DevTools WS] Binding MessagePort to WebSocket...');

      // Transition to OPEN asynchronously on next tick so listeners can attach
      setTimeout(() => {
        if (this._readyState === MessagePortWebSocket.CONNECTING) {
          this._readyState = MessagePortWebSocket.OPEN;
          console.log('[DevTools WS] WebSocket is now OPEN, firing open event');
          const openEvent = new Event('open');
          this.dispatchEvent(openEvent);

          while (this._pendingSends.length > 0 && this._readyState === MessagePortWebSocket.OPEN) {
            const data = this._pendingSends.shift();
            this._sendToPort(data);
          }
        }
      }, 0);
    }

    _sendToPort(data) {
      if (this._port) {
        console.log('[DevTools WS] Sending message to host:', data);
        this._port.postMessage(data);
      }
    }

    send(data) {
      if (this._readyState === MessagePortWebSocket.CONNECTING) {
        console.log('[DevTools WS] Buffering send while CONNECTING:', data);
        this._pendingSends.push(data);
        return;
      }
      if (this._readyState !== MessagePortWebSocket.OPEN) {
        throw new DOMException(
          "Failed to execute 'send' on 'WebSocket': Still in CONNECTING state.",
          'InvalidStateError'
        );
      }
      this._sendToPort(data);
    }

    close(code = 1000, reason = '') {
      if (this._readyState === MessagePortWebSocket.CLOSING || this._readyState === MessagePortWebSocket.CLOSED) {
        return;
      }
      this._readyState = MessagePortWebSocket.CLOSING;
      setTimeout(() => {
        this._readyState = MessagePortWebSocket.CLOSED;
        console.log('[DevTools WS] WebSocket CLOSED');
        const closeEvent = new CloseEvent('close', {
          code: code,
          reason: reason,
          wasClean: true,
        });
        this.dispatchEvent(closeEvent);
      }, 0);
    }

    _handleIncomingMessage(data) {
      console.log('[DevTools WS] Received message from host:', data);
      if (this._readyState === MessagePortWebSocket.OPEN || this._readyState === MessagePortWebSocket.CONNECTING) {
        const messageEvent = new MessageEvent('message', { data: data });
        this.dispatchEvent(messageEvent);
      }
    }

    _handleIncomingError(error) {
      const errorEvent = new Event('error');
      this.dispatchEvent(errorEvent);
    }
  }

  function initPort(port) {
    if (!port || window.__devtools_ws_port === port) {
      return;
    }
    console.log('[DevTools WS Adapter] Initializing MessagePort on iframe side');
    window.__devtools_ws_port = port;
    if (typeof port.start === 'function') {
      port.start();
    }

    port.onmessage = function (event) {
      const sockets = window.__devtools_ws_sockets || [];
      for (const socket of sockets) {
        socket._handleIncomingMessage(event.data);
      }
    };

    const sockets = window.__devtools_ws_sockets || [];
    for (const socket of sockets) {
      socket._bindPort(port);
    }
  }

  window.__initDevToolsWebSocketPort = initPort;

  window.addEventListener('message', function (event) {
    if (event.ports && event.ports.length > 0) {
      initPort(event.ports[0]);
    } else if (event.data && event.data.type === 'devtools-ws-port' && event.ports && event.ports[0]) {
      initPort(event.ports[0]);
    }
  });

  window.__originalWebSocket = OriginalWebSocket;
  window.WebSocket = MessagePortWebSocket;
})();
