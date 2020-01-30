// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.ga;

import 'dart:js';

/// Very lightweight Google Analytics integration. This class depends on having
/// the JavaScript GA library available.
class Analytics {
  Analytics();

  bool get isAvailable => _gaFunction != null;

  void sendPage({String pageName}) {
    if (pageName != null && pageName.isNotEmpty) {
      _ga2('send', 'pageview');
    } else {
      _ga3('send', 'pageview', pageName);
    }
  }

  void sendEvent(String category, String action, {String label}) {
    var m = <String, dynamic>{
      'hitType': 'event',
      'eventCategory': category,
      'eventAction': action,
    };
    if (label != null) m['eventLabel'] = label;
    _ga('send', m);
  }

  void sendTiming(String category, String variable, int valueMillis,
      {String label}) {
    var m = <String, dynamic>{
      'hitType': 'timing',
      'timingCategory': category,
      'timingVar': variable,
      'timingValue': valueMillis
    };
    if (label != null) m['timingLabel'] = label;
    _ga('send', m);
  }

  void sendException(String description, {bool fatal}) {
    var m = <String, dynamic>{
      'exDescription': description,
    };
    if (fatal != null) m['exFatal'] = fatal;
    _ga2('send', 'exception', m);
  }

  void _ga(String method, [Map args]) {
    if (isAvailable) {
      var params = <dynamic>[method];
      if (args != null) params.add(JsObject.jsify(args));
      _gaFunction.apply(params);
    }
  }

  void _ga2(String method, String type, [Map args]) {
    if (isAvailable) {
      var params = <dynamic>[method, type];
      if (args != null) params.add(JsObject.jsify(args));
      _gaFunction.apply(params);
    }
  }

  void _ga3(String method, String type, String arg, [Map args]) {
    if (isAvailable) {
      var params = <dynamic>[method, type, arg];
      if (args != null) params.add(JsObject.jsify(args));
      _gaFunction.apply(params);
    }
  }

  JsFunction get _gaFunction => context['ga'] as JsFunction;
}
