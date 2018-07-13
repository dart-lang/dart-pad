Route
=====

Route is a client routing library for Dart that helps make building
single-page web apps.

Installation
------------

Add this package to your pubspec.yaml file:

    dependencies:
      route_hierarchical: any

Then, run `pub install` to download and link in the package.

UrlMatcher
----------
Route is built around `UrlMatcher`, an interface that defines URL template
parsing, matching and reversing.


UrlTemplate
-----------
The default implementation of the `UrlMatcher` is `UrlTemplate`. As an example,
consider a blog with a home page and an article page. The article URL has the
form /article/1234. It can matched by the following template:
`/article/:articleId`.

Router
--------------

Router is a stateful object that contains routes and can perform URL routing
on those routes.

The `Router` can listen to `Window.onPopState` (or fallback to
Window.onHashChange in older browsers) events and invoke the correct
handler so that the back button seamlessly works.

Example (client.dart):

```dart
library client;

import 'package:route_hierarchical/client.dart';

main() {
  var router = new Router();
  router.root
    ..addRoute(name: 'article', path: '/article/:articleId', enter: showArticle)
    ..addRoute(name: 'home', defaultRoute: true, path: '/', enter: showHome);
  router.listen();
}

void showHome(RouteEvent e) {
  // nothing to parse from path, since there are no groups
}

void showArticle(RouteEvent e) {
  var articleId = e.parameters['articleId'];
  // show article page with loading indicator
  // load article from server, then render article
}
```

The client side router can let you define nested routes.

```dart
var router = new Router();
router.root
  ..addRoute(
     name: 'usersList',
     path: '/users',
     defaultRoute: true,
     enter: showUsersList)
  ..addRoute(
     name: 'user',
     path: '/user/:userId',
     mount: (router) =>
       router
         ..addRoute(
             name: 'articleList',
             path: '/acticles',
             defaultRoute: true,
             enter: showArticlesList)
         ..addRoute(
             name: 'article',
             path: '/article/:articleId',
             mount: (router) =>
               router
                 ..addRoute(
                     name: 'view',
                     path: '/view',
                     defaultRoute: true,
                     enter: viewArticle)
                 ..addRoute(
                     name: 'edit',
                     path: '/edit',
                     enter: editArticle)))
```

The mount parameter takes either a function that accepts an instance of a new
child router as the only parameter, or an instance of an object that implements
Routable interface.

```dart
typedef void MountFn(Router router);
```

or

```dart
abstract class Routable {
  void configureRoute(Route router);
}
```

In either case, the child router is instantiated by the parent router an
injected into the mount point, at which point child router can be configured
with new routes.

Routing with hierarchical router: when the parent router performs a prefix
match on the URL, it removes the matched part from the URL and invokes the
child router with the remaining tail.

For instance, with the above example lets consider this URL: `/user/jsmith/article/1234`.
Route "user" will match `/user/jsmith` and invoke the child router with `/article/1234`.
Route "article" will match `/article/1234` and invoke the child router with ``.
Route "view" will be matched as the default route.
The resulting route path will be: `user -> article -> view`, or simply `user.article.view`

Named Routes in Hierarchical Routers
------------------------------------

```dart
router.go('usersList');
router.go('user.articles', {'userId': 'jsmith'});
router.go('user.article.view', {
  'userId': 'jsmith',
  'articleId', 1234}
);
router.go('user.article.edit', {
  'userId': 'jsmith',
  'articleId', 1234}
);
```

If "go" is invoked on child routers, the router can automatically reconstruct
and generate the new URL from the state in the parent routers.
