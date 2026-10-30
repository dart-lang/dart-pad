// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

(function() {
  var measurementId = 'G-8KFDPZP4C3';

  function isInIframe() {
    try {
      return window.self !== window.top;
    } catch (_) {
      return true;
    }
  }

  function isChildFrame(source) {
    if (!source || source === window) return false;
    for (var i = 0; i < window.frames.length; i++) {
      if (window.frames[i] === source) return true;
    }
    return false;
  }

  var inIframe = isInIframe();
  var isEmbedded =
    inIframe ||
    new URLSearchParams(window.location.search).get('embed') === 'true';

  var initialized = false;
  function initAnalytics() {
    if (initialized) return;
    initialized = true;

    window.dataLayer = window.dataLayer || [];
    window.gtag = window.gtag || function() {
      window.dataLayer.push(arguments);
    };
    window.gtag('js', new Date());

    var config = {
      embed_mode: isEmbedded,
    };
    if (inIframe && window.location.protocol === 'https:') {
      config.cookie_flags = 'SameSite=None;Secure;Partitioned';
    }
    if (document.referrer) {
      config.page_referrer = document.referrer.split('?')[0];
    }
    window.gtag('config', measurementId, config);

    var script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + measurementId;
    document.head.appendChild(script);
  }

  if (!isEmbedded) {
    initAnalytics();
    return;
  }

  var interactionEvents = ['pointerdown', 'pointerup', 'click', 'keydown'];

  function isCookieBarEvent(event) {
    var el = event.target;
    if (el && el.nodeType !== 1) {
      el = el.parentElement;
    }
    return Boolean(
      el &&
        typeof el.closest === 'function' &&
        el.closest('.glue-cookie-notification-bar, .glue-footer')
    );
  }

  function cleanupListeners() {
    for (var i = 0; i < interactionEvents.length; i++) {
      window.removeEventListener(interactionEvents[i], onUserEvent, true);
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

  function onFrameMessage(event) {
    if (
      isChildFrame(event.source) &&
      event.data &&
      event.data.sender === 'dartpad-analytics' &&
      event.data.type === 'interaction'
    ) {
      cleanupListeners();
      initAnalytics();
    }
  }

  for (var i = 0; i < interactionEvents.length; i++) {
    window.addEventListener(interactionEvents[i], onUserEvent, true);
  }
  window.addEventListener('message', onFrameMessage, false);
})();
