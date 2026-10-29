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

  var isEmbedded =
    isInIframe() ||
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
    if (window.location.protocol === 'https:') {
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

  function cleanupListeners() {
    window.removeEventListener('pointerdown', onUserEvent, true);
    window.removeEventListener('keydown', onUserEvent, true);
    window.removeEventListener('message', onFrameMessage, false);
  }

  function onUserEvent(event) {
    if (!event.isTrusted) return;
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

  window.addEventListener('pointerdown', onUserEvent, true);
  window.addEventListener('keydown', onUserEvent, true);
  window.addEventListener('message', onFrameMessage, false);
})();
