// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:resp_client/resp_client.dart';
import 'package:resp_client/resp_commands.dart';
import 'package:resp_client/resp_server.dart';

import 'sdk.dart';

final Logger log = Logger('caching');

abstract class ServerCache {
  Future<String?> get(String key);

  Future<void> set(String key, String value, {Duration? expiration});

  Future<void> remove(String key);

  Future<void> shutdown();
}

/// A redis-backed implementation of [ServerCache].
class RedisCache implements ServerCache {
  RespClient? redisClient;
  RespServerConnection? _connection;

  final Uri redisUri;

  final Sdk _sdk;

  // Version of the server to add with keys.
  final String? serverVersion;

  // pseudo-random is good enough.
  final Random randomSource = Random();
  static const int _connectionRetryBaseMs = 250;
  static const int _connectionRetryMaxMs = 60000;
  static const Duration cacheOperationTimeout = Duration(milliseconds: 10000);

  RedisCache(String redisUriString, this._sdk, this.serverVersion)
      : redisUri = Uri.parse(redisUriString) {
    _reconnect();
  }

  Completer<void> _connected = Completer<void>();

  /// Completes when and if the redis server connects.  This future is reset
  /// on disconnection.  Mostly for testing.
  Future<void> get connected => _connected.future;

  Completer<void> _disconnected = Completer<void>()..complete();

  /// Completes when the server is disconnected (begins completed).  This
  /// future is reset on connection.  Mostly for testing.
  Future<void> get disconnected => _disconnected.future;

  String? __logPrefix;

  String get _logPrefix =>
      __logPrefix ??= 'RedisCache [$redisUri] ($serverVersion)';

  bool _isConnected() => redisClient != null && !_isShutdown;
  bool _isShutdown = false;

  /// If you will no longer be using the [RedisCache] instance, call this to
  /// prevent reconnection attempts.  All calls to get/remove/set on this object
  /// will return null after this.  Future completes when disconnection is complete.
  @override
  Future<void> shutdown() {
    log.info('$_logPrefix: shutting down...');
    _isShutdown = true;
    _connection?.close();
    return disconnected;
  }

  /// Call when an active connection has disconnected.
  void _resetConnection() {
    assert(_connected.isCompleted && !_disconnected.isCompleted);
    _connected = Completer<void>();
    _connection = null;
    redisClient = null;
    _disconnected.complete();
  }

  /// Call when a new connection is established.
  void _setUpConnection(RespServerConnection newConnection) {
    assert(_disconnected.isCompleted && !_connected.isCompleted);
    _disconnected = Completer<void>();
    _connection = newConnection;
    redisClient = RespClient(_connection!);
    _connected.complete();
  }

  /// Begin a reconnection loop asynchronously to maintain a connection to the
  /// redis server.  Never stops trying until shutdown() is called.
  void _reconnect([int retryTimeoutMs = _connectionRetryBaseMs]) {
    if (_isShutdown) {
      return;
    }
    log.info('$_logPrefix: reconnecting to $redisUri...');
    var nextRetryMs = retryTimeoutMs;
    if (retryTimeoutMs < _connectionRetryMaxMs / 2) {
      // 1 <= (randomSource.nextDouble() + 1) < 2
      nextRetryMs = (retryTimeoutMs * (randomSource.nextDouble() + 1)).toInt();
    }
    (redisUri.hasPort
            ? connectSocket(redisUri.host, port: redisUri.port)
            : connectSocket(redisUri.host))
        .then((newConnection) {
          log.info('$_logPrefix: Connected to redis server');
          _setUpConnection(newConnection);
          // If the client disconnects, discard the client and try to connect again.

          newConnection.outputSink.done.then((_) {
            _resetConnection();
            log.warning('$_logPrefix: connection terminated, reconnecting');
            _reconnect();
          }).catchError((dynamic e) {
            _resetConnection();
            log.warning(
                '$_logPrefix: connection terminated with error $e, reconnecting');
            _reconnect();
          });
        })
        .timeout(const Duration(milliseconds: _connectionRetryMaxMs))
        .catchError((_) {
          log.severe(
              '$_logPrefix: Unable to connect to redis server, reconnecting in ${nextRetryMs}ms ...');
          Future<void>.delayed(Duration(milliseconds: nextRetryMs)).then((_) {
            _reconnect(nextRetryMs);
          });
        });
  }

  /// Build a key that includes the server version, Dart SDK version, and
  /// Flutter SDK version.
  ///
  /// We don't use the existing key directly so that different AppEngine
  /// versions using the same redis cache do not have collisions.
  String _genKey(String key) {
    // the `rc` here is a differentiator to keep the `resp_client` documents
    // separate from the `dartis` documents.
    return 'server:rc:$serverVersion:'
        'dart:${_sdk.dartVersion}:'
        'flutter:${_sdk.flutterVersion}+$key';
  }

  @override
  Future<String?> get(String key) async {
    String? value;
    key = _genKey(key);
    if (!_isConnected()) {
      log.warning('$_logPrefix: no cache available when getting key $key');
    } else {
      final commands = RespCommandsTier2(redisClient!);
      try {
        value = await commands.get(key).timeout(cacheOperationTimeout,
            onTimeout: () async {
          log.warning('$_logPrefix: timeout on get operation for key $key');
          await _connection?.close();
          return null;
        });
      } catch (e) {
        log.warning('$_logPrefix: error on get operation for key $key: $e');
      }
    }
    return value;
  }

  @override
  Future<void> remove(String key) async {
    key = _genKey(key);
    if (!_isConnected()) {
      log.warning('$_logPrefix: no cache available when removing key $key');
      return;
    }

    final commands = RespCommandsTier2(redisClient!);
    try {
      await commands.del([key]).timeout(cacheOperationTimeout,
          onTimeout: () async {
        log.warning('$_logPrefix: timeout on remove operation for key $key');
        await _connection?.close();
        return 0; // 0 keys deleted
      });
    } catch (e) {
      log.warning('$_logPrefix: error on remove operation for key $key: $e');
    }
  }

  @override
  Future<void> set(String key, String value, {Duration? expiration}) async {
    key = _genKey(key);
    if (!_isConnected()) {
      log.warning('$_logPrefix: no cache available when setting key $key');
      return;
    }

    final commands = RespCommandsTier2(redisClient!);
    try {
      return Future<void>.sync(() async {
        await commands.set(key, value);
        if (expiration != null) {
          await commands.pexpire(key, expiration);
        }
      }).timeout(cacheOperationTimeout, onTimeout: () {
        log.warning('$_logPrefix: timeout on set operation for key $key');
        _connection?.close();
      });
    } catch (e) {
      log.warning('$_logPrefix: error on set operation for key $key: $e');
    }
  }
}

/// An in-memory implementation of [ServerCache] which doesn't support
/// expiration of entries based on time.
class InMemoryCache implements ServerCache {
  static const int maxSize = 512;

  final Map<String, String> _items = {};
  final List<String> _keys = [];

  @override
  Future<String?> get(String key) async {
    final result = _items[key];
    if (result != null) {
      _keys.remove(key);
      _keys.add(key);
    }
    return result;
  }

  @override
  Future<void> set(String key, String value, {Duration? expiration}) async {
    _items[key] = value;
    _keys.remove(key);
    _keys.add(key);
  }

  @override
  Future<void> remove(String key) async {
    _items.remove(key);
    _keys.remove(key);
  }

  @override
  Future<void> shutdown() => Future<void>.value();
}

/// An implementation of [ServerCache] which does not perform caching.
class NoopCache implements ServerCache {
  @override
  Future<String?> get(String key) => Future<String?>.value(null);

  @override
  Future<void> set(String key, String value, {Duration? expiration}) =>
      Future<void>.value();

  @override
  Future<void> remove(String key) => Future<void>.value();

  @override
  Future<void> shutdown() => Future<void>.value();
}
