// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/embed_runtime_limits.dart';

/// Keeps up to [maxConcurrentEmbedRuntimes] recently used runtimes across tabs.
/// Activation deliberately overlaps with cleanup; each instance writes its own key.
/// An entry exists only while its runtime is starting or active. Paused editors
/// keep their files and must explicitly activate again through Run or Resume.
final class EmbedRuntimeController {
  EmbedRuntimeController({required this.onPause, web.Window? window}) : _window = window ?? web.window {
    _id = _window.crypto.randomUUID();
    _storageSubscription = web.EventStreamProviders.storageEvent.forTarget(_window).listen(_onStorage);
    _listenForInteraction(_window, _interactionSubscriptions);
    _pageHideSubscription = web.EventStreamProviders.pageHideEvent.forTarget(_window).listen((_) => _pause());
  }

  static const storageKeyPrefix = 'dartpad.preview.session-last-seen-';
  static const entryMaxAge = Duration(hours: 6);

  final void Function() onPause;
  final web.Window _window;
  late final String _id;
  late final StreamSubscription<web.StorageEvent> _storageSubscription;
  late final StreamSubscription<web.Event> _pageHideSubscription;
  final _interactionSubscriptions = <StreamSubscription<web.Event>>[];
  final _previewSubscriptions = <StreamSubscription<web.Event>>[];
  StreamSubscription<web.Event>? _previewLoadSubscription;
  web.MutationObserver? _previewObserver;
  bool _isActive = false;

  String get _key => '$storageKeyPrefix$_id';

  void activate() {
    // Storage errors propagate to Run before expensive resources are created.
    _markRecentlyUsed();
    _isActive = true;
    _pauseIfOverLimit();
  }

  void _onStorage(web.StorageEvent event) {
    if (!_isActive || (event.key != null && !event.key!.startsWith(storageKeyPrefix))) {
      return;
    }
    try {
      if (event.storageArea == _window.localStorage) {
        // Re-read current entries rather than acting on a superseded event value.
        _pauseIfOverLimit();
      }
    } catch (_) {
      // An active runtime must retire if it can no longer coordinate.
      _pause();
    }
  }

  List<({String key, int lastSeen})> _readEntries() {
    final storage = _window.localStorage;
    final cutoff = DateTime.now().subtract(entryMaxAge).millisecondsSinceEpoch;
    // Snapshot keys because removals change Storage's index order.
    final keys = [for (var i = 0; i < storage.length; i++) ?storage.key(i)];
    final entries = <({String key, int lastSeen})>[];
    for (final key in keys.where((key) => key.startsWith(storageKeyPrefix))) {
      final raw = storage.getItem(key);
      int? lastSeen;
      try {
        final value = jsonDecode(raw ?? 'null');
        if (value case {'lastSeen': final int timestamp}) {
          lastSeen = timestamp;
        }
      } on FormatException {
        // Malformed entries in our namespace are removed like expired entries.
      }
      if (lastSeen == null || lastSeen < cutoff) {
        // Best effort: avoid deleting a value refreshed since we read it.
        if (storage.getItem(key) == raw) {
          storage.removeItem(key);
        }
      } else {
        entries.add((key: key, lastSeen: lastSeen));
      }
    }
    entries.sort((a, b) {
      final byTime = b.lastSeen.compareTo(a.lastSeen);
      return byTime != 0 ? byTime : b.key.compareTo(a.key);
    });
    return entries;
  }

  void _markRecentlyUsed() {
    final entries = _readEntries();
    var lastSeen = DateTime.now().millisecondsSinceEpoch;
    // Make a new interaction newer than entries we have already observed,
    // including multiple interactions within one clock tick. Simultaneous
    // writers can still tie; the UUID provides a consistent tie-break above.
    if (entries.isNotEmpty && entries.first.lastSeen >= lastSeen) {
      lastSeen = entries.first.lastSeen + 1;
    }
    _window.localStorage.setItem(_key, jsonEncode({'lastSeen': lastSeen}));
  }

  void _pauseIfOverLimit() {
    final mostRecentlyUsed = _readEntries().take(maxConcurrentEmbedRuntimes);
    if (!mostRecentlyUsed.any((entry) => entry.key == _key)) {
      _pause();
    }
  }

  void _onInteraction(web.Event _) {
    if (!_isActive) {
      return;
    }
    try {
      _markRecentlyUsed();
      _pauseIfOverLimit();
    } catch (_) {
      // Losing storage access must not leave an uncoordinated runtime alive.
      _pause();
    }
  }

  void _listenForInteraction(web.Window target, List<StreamSubscription<web.Event>> subscriptions) {
    for (final type in ['focus', 'pointerdown', 'keydown']) {
      subscriptions.add(
        web.EventStreamProvider<web.Event>(type).forTarget(target, useCapture: true).listen(_onInteraction),
      );
    }
  }

  /// Events inside the execution iframe do not bubble into the editor window.
  /// Detach these listeners as soon as a preview is removed to release its DOM.
  void observePreview(web.Element container) {
    _previewObserver?.disconnect();
    _previewLoadSubscription?.cancel();
    void refresh() {
      _cancelSubscriptions(_previewSubscriptions);
      final frames = container.querySelectorAll('iframe');
      for (var i = 0; i < frames.length; i++) {
        final frame = frames.item(i) as web.HTMLIFrameElement;
        final window = frame.contentWindow;
        if (window != null) {
          try {
            _listenForInteraction(window, _previewSubscriptions);
          } catch (_) {
            // Cross-origin frames cannot be observed directly.
          }
        }
      }
    }

    _previewObserver = web.MutationObserver(((JSArray<web.MutationRecord> _, web.MutationObserver _) => refresh()).toJS)
      ..observe(container, web.MutationObserverInit(childList: true, subtree: true));
    _previewLoadSubscription = web.EventStreamProviders.loadEvent
        .forTarget(container, useCapture: true)
        .listen((_) => refresh());
    refresh();
  }

  void _pause() {
    if (!_isActive) {
      return;
    }
    release();
    onPause();
  }

  /// Releases the entry after failed startup or retirement without restarting
  /// another paused instance. Its next Run must explicitly claim a place again.
  void release() {
    _isActive = false;
    try {
      _window.localStorage.removeItem(_key);
    } catch (_) {
      // Storage can become unavailable during page teardown.
    }
  }

  void dispose() {
    release();
    _previewObserver?.disconnect();
    _previewLoadSubscription?.cancel();
    _cancelSubscriptions(_previewSubscriptions);
    _cancelSubscriptions(_interactionSubscriptions);
    unawaited(_pageHideSubscription.cancel());
    unawaited(_storageSubscription.cancel());
  }

  static void _cancelSubscriptions(List<StreamSubscription<web.Event>> subscriptions) {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
  }
}
