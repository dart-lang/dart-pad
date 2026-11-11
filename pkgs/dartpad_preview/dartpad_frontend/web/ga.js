// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

(() => {
  // Keep the existing DartPad GA4 stream when moving between hosting sites.
  const measurementId = 'G-8KFDPZP4C3';

  function isInIframe() {
    try {
      return window.self !== window.top;
    } catch (_) {
      // If the frame check fails, wait for interaction before initializing.
      return true;
    }
  }

  function isChildFrame(source) {
    if (!source || source === window) return false;
    // window.frames is a WindowProxy (not iterable via for...of).
    for (let i = 0; i < window.frames.length; i++) {
      if (window.frames[i] === source) return true;
    }
    return false;
  }

  const inIframe = isInIframe();
  const isEmbedded =
    inIframe ||
    new URLSearchParams(window.location.search).get('embed') === 'true';

  let initialized = false;
  function initAnalytics() {
    if (initialized) return;
    initialized = true;

    // Queue calls until the asynchronously loaded Google tag can process them.
    window.dataLayer = window.dataLayer || [];
    window.gtag =
      window.gtag ||
      function() {
        window.dataLayer.push(arguments);
      };
    window.gtag('js', new Date());

    const config = {
      embed_mode: isEmbedded,
    };
    // Allow partitioned cookies when DartPad is embedded over HTTPS.
    if (inIframe && window.location.protocol === 'https:') {
      config.cookie_flags = 'SameSite=None;Secure;Partitioned';
    }
    if (document.referrer) {
      // Avoid including the referrer's query parameters in Analytics.
      config.page_referrer = document.referrer.split('?')[0];
    }
    window.gtag('config', measurementId, config);

    const script = document.createElement('script');
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${measurementId}`;
    document.head.appendChild(script);
  }

  if (!isEmbedded) {
    initAnalytics();
    return;
  }

  // Embedded DartPads wait for user interaction before loading Analytics.
  const interactionEvents = ['pointerdown', 'pointerup', 'click', 'keydown'];

  // Cookie controls and the footer should not trigger Analytics initialization.
  function isCookieBarEvent(event) {
    let el = event.target;
    if (el && el.nodeType !== 1) {
      el = el.parentElement;
    }
    return Boolean(
      el &&
        typeof el.closest === 'function' &&
        el.closest(
          '.glue-cookie-notification-bar, .glue-footer, .glue-cookie-notification-bar-control'
        )
    );
  }

  function cleanupListeners() {
    for (const type of interactionEvents) {
      window.removeEventListener(type, onUserEvent, true);
    }
    window.removeEventListener('message', onFrameMessage, false);
  }

  function onUserEvent(event) {
    if (!event.isTrusted) return;
    if (event.type === 'pointerdown' && event.pointerType === 'touch') return;
    if (isCookieBarEvent(event)) return;
    cleanupListeners();
    initAnalytics();
  }

  // The preview iframe forwards interaction because its events do not bubble here.
  function onFrameMessage(event) {
    if (
      isChildFrame(event.source) &&
      event.data?.sender === 'dartpad-analytics' &&
      event.data?.type === 'interaction'
    ) {
      cleanupListeners();
      initAnalytics();
    }
  }

  for (const type of interactionEvents) {
    window.addEventListener(type, onUserEvent, true);
  }
  window.addEventListener('message', onFrameMessage, false);
})();
