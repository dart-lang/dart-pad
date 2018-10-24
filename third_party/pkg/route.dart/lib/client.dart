// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library route.client;

import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:logging/logging.dart';

import 'src/utils.dart';

import 'link_matcher.dart';
import 'click_handler.dart';
import 'url_matcher.dart';
export 'url_matcher.dart';
import 'url_template.dart';

part 'route_handle.dart';

final _logger = Logger('route');
const _PATH_SEPARATOR = '.';

typedef void RoutePreEnterEventHandler(RoutePreEnterEvent event);
typedef void RouteEnterEventHandler(RouteEnterEvent event);
typedef void RoutePreLeaveEventHandler(RoutePreLeaveEvent event);
typedef void RouteLeaveEventHandler(RouteLeaveEvent event);

/// [Route] represents a node in the route tree.
abstract class Route {
  /// Name of the route. Used when querying routes.
  String get name;

  /// A path fragment [UrlMatcher] for this route.
  UrlMatcher get path;

  /// Parent route in the route tree.
  Route get parent;

  /// Indicates whether this route is currently active. Root route is always
  /// active.
  bool get isActive;

  /// Returns parameters for the currently active route. If the route is not
  /// active the getter returns null.
  Map get parameters;

  /// Returns query parameters for the currently active route. If the route is
  /// not active the getter returns null.
  Map get queryParameters;

  /// Whether to trigger the leave event when only the parameters change.
  bool get dontLeaveOnParamChanges;

  /// Used to set page title when the route [isActive].
  String get pageTitle;

  /// Returns a stream of [RouteEnterEvent] events. The [RouteEnterEvent] event
  /// is fired when route has already been made active, but before subroutes
  /// are entered. The event starts at the root and propagates from parent to
  /// child routes.
  @Deprecated("use [onEnter] instead.")
  Stream<RouteEnterEvent> get onRoute;

  /// Returns a stream of [RoutePreEnterEvent] events. The [RoutePreEnterEvent]
  /// event is fired when the route is matched during the routing, but before
  /// any previous routes were left, or any new routes were entered. The event
  /// starts at the root and propagates from parent to child routes.
  ///
  /// At this stage it's possible to veto entering of the route by calling
  /// [RoutePreEnterEvent.allowEnter] with a [Future] returns a boolean value
  /// indicating whether enter is permitted (true) or not (false).
  Stream<RoutePreEnterEvent> get onPreEnter;

  /// Returns a stream of [RoutePreLeaveEvent] events. The [RoutePreLeaveEvent]
  /// event is fired when the route is NOT matched during the routing, but before
  /// any routes are actually left, or any new routes were entered.
  ///
  /// At this stage it's possible to veto leaving of the route by calling
  /// [RoutePreLeaveEvent.allowLeave] with a [Future] returns a boolean value
  /// indicating whether enter is permitted (true) or not (false).
  Stream<RoutePreLeaveEvent> get onPreLeave;

  /// Returns a stream of [RouteLeaveEvent] events. The [RouteLeaveEvent]
  /// event is fired when the route is being left. The event starts at the leaf
  /// route and propagates from child to parent routes.
  Stream<RouteLeaveEvent> get onLeave;

  /// Returns a stream of [RouteEnterEvent] events. The [RouteEnterEvent] event
  /// is fired when route has already been made active, but before subroutes
  /// are entered.  The event starts at the root and propagates from parent
  /// to child routes.
  Stream<RouteEnterEvent> get onEnter;

  void addRoute(
      {String name,
      Pattern path,
      bool defaultRoute = false,
      RouteEnterEventHandler enter,
      RoutePreEnterEventHandler preEnter,
      RoutePreLeaveEventHandler preLeave,
      RouteLeaveEventHandler leave,
      mount,
      dontLeaveOnParamChanges = false,
      String pageTitle,
      List<Pattern> watchQueryParameters});

  /// Queries sub-routes using the [routePath] and returns the matching [Route].
  ///
  /// [routePath] is a dot-separated list of route names. Ex: foo.bar.baz, which
  /// means that current route should contain route named 'foo', the 'foo' route
  /// should contain route named 'bar', and so on.
  ///
  /// If no match is found then null is returned.
  @Deprecated("use [findRoute] instead.")
  Route getRoute(String routePath);

  /// Queries sub-routes using the [routePath] and returns the matching [Route].
  ///
  /// [routePath] is a dot-separated list of route names. Ex: foo.bar.baz, which
  /// means that current route should contain route named 'foo', the 'foo' route
  /// should contain route named 'bar', and so on.
  ///
  /// If no match is found then null is returned.
  Route findRoute(String routePath);

  /// Create an return a new [RouteHandle] for this route.
  RouteHandle newHandle();

  String toString() => '[Route: $name]';
}

/// Route is a node in the tree of routes. The edge leading to the route is
/// defined by path.
class RouteImpl extends Route {
  @override
  final String name;
  @override
  final UrlMatcher path;
  @override
  final RouteImpl parent;
  @override
  final String pageTitle;

  /// Child routes map route names to `Route` instances
  final _routes = <String, RouteImpl>{};

  final StreamController<RouteEnterEvent> _onEnterController;
  final StreamController<RoutePreEnterEvent> _onPreEnterController;
  final StreamController<RoutePreLeaveEvent> _onPreLeaveController;
  final StreamController<RouteLeaveEvent> _onLeaveController;

  final List<Pattern> _watchQueryParameters;

  /// The default child route
  RouteImpl _defaultRoute;

  /// The currently active child route
  RouteImpl _currentRoute;
  RouteEvent _lastEvent;
  @override
  final bool dontLeaveOnParamChanges;

  @override
  @Deprecated("use [onEnter] instead.")
  Stream<RouteEnterEvent> get onRoute => onEnter;
  @override
  Stream<RoutePreEnterEvent> get onPreEnter => _onPreEnterController.stream;
  @override
  Stream<RoutePreLeaveEvent> get onPreLeave => _onPreLeaveController.stream;
  @override
  Stream<RouteLeaveEvent> get onLeave => _onLeaveController.stream;
  @override
  Stream<RouteEnterEvent> get onEnter => _onEnterController.stream;

  RouteImpl._new(
      {this.name,
      this.path,
      this.parent,
      this.dontLeaveOnParamChanges = false,
      this.pageTitle,
      List<Pattern> watchQueryParameters})
      : _onEnterController =
            StreamController<RouteEnterEvent>.broadcast(sync: true),
        _onPreEnterController =
            StreamController<RoutePreEnterEvent>.broadcast(sync: true),
        _onPreLeaveController =
            StreamController<RoutePreLeaveEvent>.broadcast(sync: true),
        _onLeaveController =
            StreamController<RouteLeaveEvent>.broadcast(sync: true),
        _watchQueryParameters = watchQueryParameters;

  @override
  void addRoute(
      {String name,
      Pattern path,
      bool defaultRoute = false,
      RouteEnterEventHandler enter,
      RoutePreEnterEventHandler preEnter,
      RoutePreLeaveEventHandler preLeave,
      RouteLeaveEventHandler leave,
      mount,
      dontLeaveOnParamChanges = false,
      String pageTitle,
      List<Pattern> watchQueryParameters}) {
    if (name == null) {
      throw ArgumentError('name is required for all routes');
    }
    if (name.contains(_PATH_SEPARATOR)) {
      throw ArgumentError('name cannot contain dot.');
    }
    if (_routes.containsKey(name)) {
      throw ArgumentError('Route $name already exists');
    }

    var matcher = path is UrlMatcher ? path : UrlTemplate(path.toString());

    var route = RouteImpl._new(
        name: name,
        path: matcher,
        parent: this,
        dontLeaveOnParamChanges: dontLeaveOnParamChanges,
        pageTitle: pageTitle,
        watchQueryParameters: watchQueryParameters);

    route
      ..onPreEnter.listen(preEnter)
      ..onPreLeave.listen(preLeave)
      ..onEnter.listen(enter)
      ..onLeave.listen(leave);

    if (mount != null) {
      if (mount is Function) {
        mount(route);
      } else if (mount is Routable) {
        mount.configureRoute(route);
      }
    }

    if (defaultRoute) {
      if (_defaultRoute != null) {
        throw StateError('Only one default route can be added.');
      }
      _defaultRoute = route;
    }
    _routes[name] = route;
  }

  @override
  Route getRoute(String routePath) => findRoute(routePath);

  @override
  Route findRoute(String routePath) {
    RouteImpl currentRoute = this;
    List<String> subRouteNames = routePath.split(_PATH_SEPARATOR);
    while (subRouteNames.isNotEmpty) {
      var routeName = subRouteNames.removeAt(0);
      currentRoute = currentRoute._routes[routeName];
      if (currentRoute == null) {
        _logger.warning('Invalid route name: $routeName $_routes');
        return null;
      }
    }
    return currentRoute;
  }

  String _getHead(String tail) {
    for (RouteImpl route = this; route.parent != null; route = route.parent) {
      var currentRoute = route.parent._currentRoute;
      if (currentRoute == null) {
        throw StateError('Route ${route.parent.name} has no current route.');
      }

      tail = currentRoute._reverse(tail);
    }
    return tail;
  }

  String _getTailUrl(Route routeToGo, Map parameters) {
    var tail = '';
    for (RouteImpl route = routeToGo; route != this; route = route.parent) {
      tail = route.path.reverse(
          parameters: _joinParams(
              parameters == null ? route.parameters : parameters,
              route._lastEvent),
          tail: tail);
    }
    return tail;
  }

  Map _joinParams(Map parameters, RouteEvent lastEvent) =>
      lastEvent == null ? parameters : Map.from(lastEvent.parameters)
        ..addAll(parameters);

  /// Returns a URL for this route. The tail (url generated by the child path)
  /// will be passes to the UrlMatcher to be properly appended in the
  /// right place.
  String _reverse(String tail) =>
      path.reverse(parameters: _lastEvent.parameters, tail: tail);

  /// Create an return a new [RouteHandle] for this route.
  @override
  RouteHandle newHandle() {
    _logger.finest('newHandle for $this');
    return RouteHandle._new(this);
  }

  /// Indicates whether this route is currently active. Root route is always
  /// active.
  @override
  bool get isActive =>
      parent == null ? true : identical(parent._currentRoute, this);

  /// Returns parameters for the currently active route. If the route is not
  /// active the getter returns null.
  @override
  Map get parameters {
    if (isActive) {
      return _lastEvent == null ? const {} : Map.from(_lastEvent.parameters);
    }
    return null;
  }

  /// Returns parameters for the currently active route. If the route is not
  /// active the getter returns null.
  @override
  Map get queryParameters {
    if (isActive) {
      return _lastEvent == null
          ? const {}
          : Map.from(_lastEvent.queryParameters);
    }
    return null;
  }
}

/// Route enter or leave event.
abstract class RouteEvent {
  final String path;
  final Map parameters;
  final Map queryParameters;
  final Route route;

  RouteEvent(this.path, this.parameters, this.queryParameters, this.route);
}

class RoutePreEnterEvent extends RouteEvent {
  final _allowEnterFutures = <Future<bool>>[];

  RoutePreEnterEvent(path, parameters, queryParameters, route)
      : super(path, parameters, queryParameters, route);

  RoutePreEnterEvent._fromMatch(_Match m)
      : this(m.urlMatch.tail, m.urlMatch.parameters, {}, m.route);

  /// Can be called with a future which will complete with a boolean
  /// value allowing (true) or disallowing (false) the current navigation.
  void allowEnter(Future<bool> allow) {
    _allowEnterFutures.add(allow);
  }
}

class RouteEnterEvent extends RouteEvent {
  RouteEnterEvent(path, parameters, queryParameters, route)
      : super(path, parameters, queryParameters, route);

  RouteEnterEvent._fromMatch(_Match m)
      : this(m.urlMatch.match, m.urlMatch.parameters, m.queryParameters,
            m.route);
}

class RouteLeaveEvent extends RouteEvent {
  RouteLeaveEvent(route) : super('', {}, {}, route);
}

class RoutePreLeaveEvent extends RouteEvent {
  final _allowLeaveFutures = <Future<bool>>[];

  RoutePreLeaveEvent(route) : super('', {}, {}, route);

  /// Can be called with a future which will complete with a boolean
  /// value allowing (true) or disallowing (false) the current navigation.
  void allowLeave(Future<bool> allow) {
    _allowLeaveFutures.add(allow);
  }
}

/// Event emitted when routing starts.
class RouteStartEvent {
  /// URI that was passed to [Router.route].
  final String uri;

  /// Future that completes to a boolean value of whether the routing was
  /// successful.
  final Future<bool> completed;

  RouteStartEvent._new(this.uri, this.completed);
}

abstract class Routable {
  void configureRoute(Route router);
}

/// Stores a set of [UrlPattern] to [Handler] associations and provides methods
/// for calling a handler for a URL path, listening to [Window] history events,
/// and creating HTML event handlers that navigate to a URL.
class Router {
  final bool _useFragment;
  final Window _window;
  final Route root;
  final _onRouteStart = StreamController<RouteStartEvent>.broadcast(sync: true);
  final bool sortRoutes;
  bool _listen = false;
  WindowClickHandler _clickHandler;

  /// [useFragment] determines whether this Router uses pure paths with
  /// [History.pushState] or paths + fragments and [Location.assign]. The default
  /// value is null which then determines the behavior based on
  /// [History.supportsState].
  Router(
      {bool useFragment,
      Window windowImpl,
      bool sortRoutes = true,
      RouterLinkMatcher linkMatcher,
      WindowClickHandler clickHandler})
      : this._init(null,
            useFragment: useFragment,
            windowImpl: windowImpl,
            sortRoutes: sortRoutes,
            linkMatcher: linkMatcher,
            clickHandler: clickHandler);

  Router._init(Router parent,
      {bool useFragment,
      Window windowImpl,
      this.sortRoutes,
      RouterLinkMatcher linkMatcher,
      WindowClickHandler clickHandler})
      : _useFragment =
            (useFragment == null) ? !History.supportsState : useFragment,
        _window = (windowImpl == null) ? window : windowImpl,
        root = RouteImpl._new() {
    if (clickHandler == null) {
      if (linkMatcher == null) {
        linkMatcher = DefaultRouterLinkMatcher();
      }
      _clickHandler = DefaultWindowClickHandler(
          linkMatcher, this, _useFragment, _window, _normalizeHash);
    } else {
      _clickHandler = clickHandler;
    }
  }

  /// A stream of route calls.
  Stream<RouteStartEvent> get onRouteStart => _onRouteStart.stream;

  /// Finds a matching [Route] added with [addRoute], parses the path
  /// and invokes the associated callback. Search for the matching route starts
  /// at [startingFrom] route or the root [Route] if not specified. By default
  /// the common path from [startingFrom] to the current active path and target
  /// path will be ignored (i.e. no leave or enter will be executed on them).
  ///
  /// This method does not perform any navigation, [go] should be used for that.
  /// This method is used to invoke a handler after some other code navigates the
  /// window, such as [listen].
  ///
  /// Setting [forceReload] to true (default false) will force the matched routes
  /// to reload, even if they are already active and none of the parameters
  /// changed.
  Future<bool> route(String path,
      {Route startingFrom, bool forceReload = false}) {
    _logger.finest('route path=$path startingFrom=$startingFrom '
        'forceReload=$forceReload');
    var baseRoute;
    List<Route> trimmedActivePath;
    if (startingFrom == null) {
      baseRoute = root;
      trimmedActivePath = activePath;
    } else {
      baseRoute = _dehandle(startingFrom);
      trimmedActivePath = activePath.sublist(activePath.indexOf(baseRoute) + 1);
    }

    var treePath = _matchingTreePath(path, baseRoute);
    // Figure out the list of routes that will be leaved
    var future =
        _preLeave(path, treePath, trimmedActivePath, baseRoute, forceReload);
    _onRouteStart.add(RouteStartEvent._new(path, future));
    return future;
  }

  /// Called before leaving the current route.
  ///
  /// If none of the preLeave listeners veto the leave, chain call [_preEnter].
  ///
  /// If at least one preLeave listeners veto the leave, returns a Future that
  /// will resolve to false. The current route will not change.
  Future<bool> _preLeave(String path, List<_Match> treePath,
      List<RouteImpl> activePath, RouteImpl baseRoute, bool forceReload) {
    Iterable<RouteImpl> mustLeave = activePath;
    var leaveBase = baseRoute;
    for (var i = 0, ll = min(activePath.length, treePath.length); i < ll; i++) {
      if (mustLeave.first == treePath[i].route &&
          (treePath[i].route.dontLeaveOnParamChanges ||
              !(forceReload ||
                  _paramsChanged(treePath[i].route, treePath[i])))) {
        mustLeave = mustLeave.skip(1);
        leaveBase = leaveBase._currentRoute;
      } else {
        break;
      }
    }
    // Reverse the list to ensure child is left before the parent.
    mustLeave = mustLeave.toList().reversed;

    var preLeaving = <Future<bool>>[];
    mustLeave.forEach((toLeave) {
      var event = RoutePreLeaveEvent(toLeave);
      toLeave._onPreLeaveController.add(event);
      preLeaving.addAll(event._allowLeaveFutures);
    });
    return Future.wait(preLeaving).then<bool>((List<bool> results) {
      if (!results.any((r) => r == false)) {
        var leaveFn = () => _leave(mustLeave, leaveBase);
        return _preEnter(
            path, treePath, activePath, baseRoute, leaveFn, forceReload);
      }
      return Future.value(false);
    });
  }

  void _leave(Iterable<Route> mustLeave, Route leaveBase) {
    mustLeave.forEach((toLeave) {
      var event = RouteLeaveEvent(toLeave);
      (toLeave as dynamic)._onLeaveController.add(event);
    });
    if (!mustLeave.isEmpty) {
      _unsetAllCurrentRoutesRecursively(leaveBase);
    }
  }

  void _unsetAllCurrentRoutesRecursively(RouteImpl r) {
    if (r._currentRoute != null) {
      _unsetAllCurrentRoutesRecursively(r._currentRoute);
      r._currentRoute = null;
    }
  }

  Future<bool> _preEnter(
      String path,
      List<_Match> treePath,
      List<Route> activePath,
      RouteImpl baseRoute,
      Function leaveFn,
      bool forceReload) {
    Iterable<_Match> toEnter = treePath;
    var tail = path;
    var enterBase = baseRoute;
    for (var i = 0, ll = min(toEnter.length, activePath.length); i < ll; i++) {
      if (toEnter.first.route == activePath[i] &&
          !(forceReload || _paramsChanged(activePath[i], treePath[i]))) {
        tail = treePath[i].urlMatch.tail;
        toEnter = toEnter.skip(1);
        enterBase = enterBase._currentRoute;
      } else {
        break;
      }
    }
    if (toEnter.isEmpty) {
      leaveFn();
      return Future.value(true);
    }

    var preEnterFutures = <Future<bool>>[];
    toEnter.forEach((_Match matchedRoute) {
      var preEnterEvent = RoutePreEnterEvent._fromMatch(matchedRoute);
      matchedRoute.route._onPreEnterController.add(preEnterEvent);
      preEnterFutures.addAll(preEnterEvent._allowEnterFutures);
    });
    return Future.wait(preEnterFutures).then<bool>((List<bool> results) {
      if (!results.any((v) => v == false)) {
        leaveFn();
        _enter(enterBase, toEnter, tail);
        return Future.value(true);
      }
      return Future.value(false);
    });
  }

  void _enter(RouteImpl startingFrom, Iterable<_Match> treePath, String path) {
    var base = startingFrom;
    treePath.forEach((_Match matchedRoute) {
      var event = RouteEnterEvent._fromMatch(matchedRoute);
      base._currentRoute = matchedRoute.route;
      base._currentRoute._lastEvent = event;
      matchedRoute.route._onEnterController.add(event);
      base = matchedRoute.route;
    });
  }

  /// Returns the direct child routes of [baseRoute] matching the given [path]
  List<RouteImpl> _matchingRoutes(String path, RouteImpl baseRoute) {
    var routes = baseRoute._routes.values
        .where((RouteImpl r) => r.path.match(path) != null)
        .toList();

    return sortRoutes
        ? (routes..sort((r1, r2) => r1.path.compareTo(r2.path)))
        : routes;
  }

  /// Returns the path as a list of [_Match]
  List<_Match> _matchingTreePath(String path, RouteImpl baseRoute) {
    final treePath = <_Match>[];
    Route matchedRoute;
    do {
      matchedRoute = null;
      List matchingRoutes = _matchingRoutes(path, baseRoute);
      if (matchingRoutes.isNotEmpty) {
        if (matchingRoutes.length > 1) {
          _logger.fine("More than one route matches $path $matchingRoutes");
        }
        matchedRoute = matchingRoutes.first;
      } else {
        if (baseRoute._defaultRoute != null) {
          matchedRoute = baseRoute._defaultRoute;
        }
      }
      if (matchedRoute != null) {
        var match = _getMatch(matchedRoute, path);
        treePath.add(match);
        baseRoute = matchedRoute;
        path = match.urlMatch.tail;
      }
    } while (matchedRoute != null);
    return treePath;
  }

  bool _paramsChanged(RouteImpl route, _Match match) {
    var lastEvent = route._lastEvent;
    return lastEvent == null ||
        lastEvent.path != match.urlMatch.match ||
        !mapsShallowEqual(lastEvent.parameters, match.urlMatch.parameters) ||
        !mapsShallowEqual(
            _filterQueryParams(
                lastEvent.queryParameters, route._watchQueryParameters),
            _filterQueryParams(
                match.queryParameters, route._watchQueryParameters));
  }

  Map _filterQueryParams(
      Map queryParameters, List<Pattern> watchQueryParameters) {
    if (watchQueryParameters == null) {
      return queryParameters;
    }
    Map result = {};
    queryParameters.keys.forEach((key) {
      if (watchQueryParameters
          .any((pattern) => pattern.matchAsPrefix(key) != null)) {
        result[key] = queryParameters[key];
      }
    });
    return result;
  }

  Future<bool> reload({Route startingFrom}) {
    var path = activePath;
    RouteImpl baseRoute = startingFrom == null ? root : _dehandle(startingFrom);
    if (baseRoute != root) {
      path = path.skipWhile((r) => r != baseRoute).skip(1).toList();
    }
    String reloadPath = '';
    for (int i = path.length - 1; i >= 0; i--) {
      reloadPath = (path[i] as dynamic)._reverse(reloadPath);
    }
    reloadPath += _buildQuery(path.isEmpty ? {} : path.last.queryParameters);
    return route(reloadPath, startingFrom: startingFrom, forceReload: true);
  }

  /// Navigates to a given relative route path, and parameters.
  Future<bool> go(String routePath, Map parameters,
      {Route startingFrom,
      bool replace = false,
      Map queryParameters,
      bool forceReload = false}) {
    RouteImpl baseRoute = startingFrom == null ? root : _dehandle(startingFrom);
    var routeToGo = _findRoute(baseRoute, routePath);
    var newTail = baseRoute._getTailUrl(routeToGo, parameters) +
        _buildQuery(queryParameters);
    String newUrl = baseRoute._getHead(newTail);
    _logger.finest('go $newUrl');
    return route(newTail, startingFrom: baseRoute, forceReload: forceReload)
        .then((success) {
      if (success) {
        _go(newUrl, routeToGo.pageTitle, replace);
      }
      return success;
    });
  }

  /// Returns an absolute URL for a given relative route path and parameters.
  String url(String routePath,
      {Route startingFrom, Map parameters, Map queryParameters}) {
    var baseRoute = startingFrom == null ? root : _dehandle(startingFrom);
    parameters = parameters == null ? {} : parameters;
    var routeToGo = _findRoute(baseRoute, routePath);
    var tail = (baseRoute as dynamic)._getTailUrl(routeToGo, parameters);
    return (_useFragment ? '#' : '') +
        (baseRoute as dynamic)._getHead(tail) +
        _buildQuery(queryParameters);
  }

  /// Attempts to find [Route] for the specified [routePath] relative to the
  /// [baseRoute]. If nothing is found throws a [StateError].
  Route _findRoute(Route baseRoute, String routePath) {
    var route = baseRoute.findRoute(routePath);
    if (route == null) {
      throw StateError('Invalid route path: $routePath');
    }
    return route;
  }

  /// Build an query string from a parameter `Map`
  String _buildQuery(Map queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return '';
    }
    return '?' +
        queryParams.keys
            .map((key) => '$key=${Uri.encodeComponent(queryParams[key])}')
            .join('&');
  }

  Route _dehandle(Route r) => r is RouteHandle ? r._getHost(r) : r;

  _Match _getMatch(Route route, String path) {
    var match = route.path.match(path);
    // default route
    if (match == null) {
      return _Match(route, UrlMatch('', '', {}), {});
    }
    return _Match(route, match, _parseQuery(route, path));
  }

  /// Parse the query string to a parameter `Map`
  Map<String, String> _parseQuery(Route route, String path) {
    var params = <String, String>{};
    if (path.indexOf('?') == -1) return params;
    var queryStr = path.substring(path.indexOf('?') + 1);
    queryStr.split('&').forEach((String keyValPair) {
      List<String> keyVal = _parseKeyVal(keyValPair);
      var key = keyVal[0];
      if (key.isNotEmpty) {
        params[key] = Uri.decodeComponent(keyVal[1]);
      }
    });
    return params;
  }

  /// Parse a key value pair (`"key=value"`) and returns a list of
  /// `["key", "value"]`.
  List<String> _parseKeyVal(String kvPair) {
    if (kvPair.isEmpty) {
      return const ['', ''];
    }
    var splitPoint = kvPair.indexOf('=');

    return (splitPoint == -1)
        ? [kvPair, '']
        : [kvPair.substring(0, splitPoint), kvPair.substring(splitPoint + 1)];
  }

  /// Listens for window history events and invokes the router. On older
  /// browsers the hashChange event is used instead.
  void listen({bool ignoreClick = false, Element appRoot}) {
    _logger.finest('listen ignoreClick=$ignoreClick');
    if (_listen) {
      throw StateError('listen can only be called once');
    }
    _listen = true;
    if (_useFragment) {
      _window.onHashChange.listen((_) {
        route(_normalizeHash(_window.location.hash)).then((allowed) {
          // if not allowed, we need to restore the browser location
          if (!allowed) {
            _window.history.back();
          }
        });
      });
      route(_normalizeHash(_window.location.hash));
    } else {
      String getPath() =>
          '${_window.location.pathname}${_window.location.search}'
          '${_window.location.hash}';

      _window.onPopState.listen((_) {
        route(getPath()).then((allowed) {
          // if not allowed, we need to restore the browser location
          if (!allowed) {
            _window.history.back();
          }
        });
      });
      route(getPath());
    }
    if (!ignoreClick) {
      if (appRoot == null) {
        appRoot = _window.document.documentElement;
      }
      _logger.finest('listen on win');
      appRoot.onClick
          .where((MouseEvent e) => !(e.ctrlKey || e.metaKey || e.shiftKey))
          .listen(_clickHandler);
    }
  }

  String _normalizeHash(String hash) => hash.isEmpty ? '' : hash.substring(1);

  /// Navigates the browser to the path produced by [url] with [args] by calling
  /// [History.pushState], then invokes the handler associated with [url].
  ///
  /// On older browsers [Location.assign] is used instead with the fragment
  /// version of the UrlPattern.
  Future<bool> gotoUrl(String url) => route(url).then((success) {
        if (success) {
          _go(url, null, false);
        }
      });

  void _go(String path, String title, bool replace) {
    if (_useFragment) {
      if (replace) {
        _window.location.replace('#$path');
      } else {
        _window.location.assign('#$path');
      }
    } else {
      if (title == null) {
        title = (_window.document as HtmlDocument).title;
      }
      if (replace) {
        _window.history.replaceState(null, title, path);
      } else {
        _window.history.pushState(null, title, path);
      }
    }
    if (title != null) {
      (_window.document as HtmlDocument).title = title;
    }
  }

  /// Returns the current active route path in the route tree.
  /// Excludes the root path.
  List<Route> get activePath {
    var res = <RouteImpl>[];
    dynamic route = root;
    while (route._currentRoute != null) {
      route = route._currentRoute;
      res.add(route);
    }
    return res;
  }

  /// A shortcut for router.root.findRoute().
  Route findRoute(String routePath) => root.findRoute(routePath);
}

class _Match {
  final RouteImpl route;
  final UrlMatch urlMatch;
  final Map queryParameters;

  _Match(this.route, this.urlMatch, this.queryParameters);

  String toString() => route.toString();
}
