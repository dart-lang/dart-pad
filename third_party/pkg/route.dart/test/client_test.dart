// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library route.client_test;

import 'dart:async';
import 'dart:html';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:route_hierarchical/client.dart';

import 'util/mocks.dart';

main() {
  test('paths are routed to routes added with addRoute', () {
    var router = Router();
    router.root.addRoute(
        name: 'foo',
        path: '/foo',
        enter: expectAsync1((RouteEvent e) {
          expect(e.path, '/foo');
          expect(router.root.findRoute('foo').isActive, isTrue);
        }));
    return router.route('/foo');
  });

  group('use a longer path first', () {
    test('add a longer path first', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'foobar',
            path: '/foo/bar',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/foo/bar');
              expect(router.root.findRoute('foobar').isActive, isTrue);
            }))
        ..addRoute(
            name: 'foo',
            path: '/foo',
            enter: (e) => fail('should invoke /foo/bar'));
      return router.route('/foo/bar');
    });

    test('add a longer path last', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            enter: (e) => fail('should invoke /foo/bar'))
        ..addRoute(
            name: 'foobar',
            path: '/foo/bar',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/foo/bar');
              expect(router.root.findRoute('foobar').isActive, isTrue);
            }));
      return router.route('/foo/bar');
    });

    test('add paths with a param', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            enter: (e) => fail('should invoke /foo/bar'))
        ..addRoute(
            name: 'fooparam',
            path: '/foo/:param',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/foo/bar');
              expect(router.root.findRoute('fooparam').isActive, isTrue);
            }));
      return router.route('/foo/bar');
    });

    test('add paths with a parametalized parent', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'paramaddress',
            path: '/:zzzzzz/address',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/foo/address');
              expect(router.root.findRoute('paramaddress').isActive, isTrue);
            }))
        ..addRoute(
            name: 'param_add',
            path: '/:aaaaaa/add',
            enter: (e) => fail('should invoke /foo/address'));
      return router.route('/foo/address');
    });

    test('add paths with a first param and one without', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'fooparam',
            path: '/:param/foo',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/bar/foo');
              expect(router.root.findRoute('fooparam').isActive, isTrue);
            }))
        ..addRoute(
            name: 'bar',
            path: '/bar',
            enter: (e) => fail('should enter fooparam'));
      return router.route('/bar/foo');
    });

    test('add paths with a first param and one without 2', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'paramfoo',
            path: '/:param/foo',
            enter: (e) => fail('should enter barfoo'))
        ..addRoute(
            name: 'barfoo',
            path: '/bar/foo',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/bar/foo');
              expect(router.root.findRoute('barfoo').isActive, isTrue);
            }));
      return router.route('/bar/foo');
    });

    test('add paths with a second param and one without', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'bazparamfoo',
            path: '/baz/:param/foo',
            enter: (e) => fail('should enter bazbarfoo'))
        ..addRoute(
            name: 'bazbarfoo',
            path: '/baz/bar/foo',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/baz/bar/foo');
              expect(router.root.findRoute('bazbarfoo').isActive, isTrue);
            }));
      return router.route('/baz/bar/foo');
    });

    test('add paths with a first param and a second param', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'parambarfoo',
            path: '/:param/bar/foo',
            enter: (e) => fail('should enter bazparamfoo'))
        ..addRoute(
            name: 'bazparamfoo',
            path: '/baz/:param/foo',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/baz/bar/foo');
              expect(router.root.findRoute('bazparamfoo').isActive, isTrue);
            }));
      return router.route('/baz/bar/foo');
    });

    test('add paths with two params and a param', () {
      Router router = Router();
      router.root
        ..addRoute(
            name: 'param1param2foo',
            path: '/:param1/:param2/foo',
            enter: (e) => fail('should enter bazparamfoo'))
        ..addRoute(
            name: 'param1barfoo',
            path: '/:param1/bar/foo',
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, '/baz/bar/foo');
              expect(router.root.findRoute('param1barfoo').isActive, isTrue);
            }));
      return router.route('/baz/bar/foo');
    });
  });

  group('hierarchical routing', () {
    void _testParentChild(Pattern parentPath, Pattern childPath,
        String expectedParentPath, String expectedChildPath, String testPath) {
      var router = Router();
      router.root.addRoute(
          name: 'parent',
          path: parentPath,
          enter: expectAsync1((RouteEvent e) {
            expect(e.path, expectedParentPath);
            expect(e.route, isNotNull);
            expect(e.route.name, 'parent');
          }),
          mount: (Route child) {
            child.addRoute(
                name: 'child',
                path: childPath,
                enter: expectAsync1((RouteEvent e) {
                  expect(e.path, expectedChildPath);
                }));
          });
      router.route(testPath);
    }

    test('child router with Strings', () {
      _testParentChild('/foo', '/bar', '/foo', '/bar', '/foo/bar');
    });
  });

  group('reload', () {
    test('should not reload when no active path', () {
      var router = Router();
      var counters = {
        'fooLeave': 0,
        'fooEnter': 0,
      };
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            leave: (_) => counters['fooLeave']++,
            enter: (_) => counters['fooEnter']++);

      return router.reload().then((_) {
        expect(counters, {
          'fooLeave': 0,
          'fooEnter': 0,
        });
      });
    });

    test('should reload currently active route', () {
      var router = Router();
      var counters = {
        'fooLeave': 0,
        'fooEnter': 0,
        'barLeave': 0,
        'barEnter': 0,
      };
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            leave: (_) => counters['fooLeave']++,
            enter: (_) => counters['fooEnter']++,
            mount: (r) => r.addRoute(
                name: 'bar',
                path: '/:bar',
                leave: (_) => counters['barLeave']++,
                enter: (_) => counters['barEnter']++));

      return router.route('/123').then((_) {
        expect(counters, {
          'fooLeave': 0,
          'fooEnter': 1,
          'barLeave': 0,
          'barEnter': 0,
        });
        return router.reload().then((_) {
          expect(counters, {
            'fooLeave': 1,
            'fooEnter': 2,
            'barLeave': 0,
            'barEnter': 0,
          });
          expect(router.findRoute('foo').parameters['foo'], '123');
        });
      });
    });

    test('should reload currently active route from startingFrom', () {
      var router = Router();
      var counters = {
        'fooLeave': 0,
        'fooEnter': 0,
        'barLeave': 0,
        'barEnter': 0,
      };
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            leave: (_) => counters['fooLeave']++,
            enter: (_) => counters['fooEnter']++,
            mount: (r) => r.addRoute(
                name: 'bar',
                path: '/:bar',
                leave: (_) => counters['barLeave']++,
                enter: (_) => counters['barEnter']++));

      return router.route('/123/321').then((_) {
        expect(counters, {
          'fooLeave': 0,
          'fooEnter': 1,
          'barLeave': 0,
          'barEnter': 1,
        });
        return router.reload(startingFrom: router.findRoute('foo')).then((_) {
          expect(counters, {
            'fooLeave': 0,
            'fooEnter': 1,
            'barLeave': 1,
            'barEnter': 2,
          });
          expect(router.findRoute('foo').parameters['foo'], '123');
          expect(router.findRoute('foo.bar').parameters['bar'], '321');
        });
      });
    });

    test('should preserve param values on reload', () {
      var router = Router();
      var counters = {
        'fooLeave': 0,
        'fooEnter': 0,
        'barLeave': 0,
        'barEnter': 0,
      };
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            leave: (_) => counters['fooLeave']++,
            enter: (_) => counters['fooEnter']++,
            mount: (r) => r.addRoute(
                name: 'bar',
                path: '/:bar',
                leave: (_) => counters['barLeave']++,
                enter: (_) => counters['barEnter']++));

      return router.route('/123/321').then((_) {
        expect(counters, {
          'fooLeave': 0,
          'fooEnter': 1,
          'barLeave': 0,
          'barEnter': 1,
        });
        return router.reload().then((_) {
          expect(counters, {
            'fooLeave': 1,
            'fooEnter': 2,
            'barLeave': 1,
            'barEnter': 2,
          });
          expect(router.findRoute('foo').parameters['foo'], '123');
          expect(router.findRoute('foo.bar').parameters['bar'], '321');
        });
      });
    });

    test('should preserve query param values on reload', () {
      var router = Router();
      var counters = {
        'fooLeave': 0,
        'fooEnter': 0,
      };
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            leave: (_) => counters['fooLeave']++,
            enter: (_) => counters['fooEnter']++);

      return router.route('/123?foo=bar&blah=blah').then((_) {
        expect(counters, {
          'fooLeave': 0,
          'fooEnter': 1,
        });
        expect(router.findRoute('foo').queryParameters, {
          'foo': 'bar',
          'blah': 'blah',
        });
        return router.reload().then((_) {
          expect(router.findRoute('foo').queryParameters, {
            'foo': 'bar',
            'blah': 'blah',
          });
        });
      });
    });

    test('should preserve query param values on reload from the middle', () {
      var router = Router();
      var counters = {
        'fooLeave': 0,
        'fooEnter': 0,
        'barLeave': 0,
        'barEnter': 0,
      };
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            leave: (_) => counters['fooLeave']++,
            enter: (_) => counters['fooEnter']++,
            mount: (r) => r.addRoute(
                name: 'bar',
                path: '/:bar',
                leave: (_) => counters['barLeave']++,
                enter: (_) => counters['barEnter']++));

      return router.route('/123/321?foo=bar&blah=blah').then((_) {
        expect(counters, {
          'fooLeave': 0,
          'fooEnter': 1,
          'barLeave': 0,
          'barEnter': 1,
        });
        expect(router.findRoute('foo').queryParameters, {
          'foo': 'bar',
          'blah': 'blah',
        });
        return router.reload(startingFrom: router.findRoute('foo')).then((_) {
          expect(counters, {
            'fooLeave': 0,
            'fooEnter': 1,
            'barLeave': 1,
            'barEnter': 2,
          });
          expect(router.findRoute('foo').queryParameters, {
            'foo': 'bar',
            'blah': 'blah',
          });
          expect(router.findRoute('foo').parameters['foo'], '123');
          expect(router.findRoute('foo.bar').parameters['bar'], '321');
        });
      });
    });
  });

  group('leave', () {
    test('should leave previous route and enter new', () {
      var counters = <String, int>{
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0,
        'bazPreEnter': 0,
        'bazPreLeave': 0,
        'bazEnter': 0,
        'bazLeave': 0
      };
      var router = Router();
      router.root
        ..addRoute(
            path: '/foo',
            name: 'foo',
            preEnter: (_) => counters['fooPreEnter']++,
            preLeave: (_) => counters['fooPreLeave']++,
            enter: (_) => counters['fooEnter']++,
            leave: (_) => counters['fooLeave']++,
            watchQueryParameters: [],
            mount: (Route route) => route
              ..addRoute(
                  path: '/bar',
                  name: 'bar',
                  preEnter: (_) => counters['barPreEnter']++,
                  preLeave: (_) => counters['barPreLeave']++,
                  enter: (_) => counters['barEnter']++,
                  leave: (_) => counters['barLeave']++)
              ..addRoute(
                  path: '/baz',
                  name: 'baz',
                  preEnter: (_) => counters['bazPreEnter']++,
                  preLeave: (_) => counters['bazPreLeave']++,
                  enter: (_) => counters['bazEnter']++,
                  leave: (_) => counters['bazLeave']++,
                  watchQueryParameters: ['baz.blah']));

      expect(counters, {
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0,
        'bazPreEnter': 0,
        'bazPreLeave': 0,
        'bazEnter': 0,
        'bazLeave': 0
      });
      router
          .route('/foo/bar')
          .then(expectAsync1((_) {
            expect(counters, {
              'fooPreEnter': 1,
              'fooPreLeave': 0,
              'fooEnter': 1,
              'fooLeave': 0,
              'barPreEnter': 1,
              'barPreLeave': 0,
              'barEnter': 1,
              'barLeave': 0,
              'bazPreEnter': 0,
              'bazPreLeave': 0,
              'bazEnter': 0,
              'bazLeave': 0
            });
          }))
          .then(expectAsync1(
              (_) => router.route('/foo/baz').then(expectAsync1((_) {
                    expect(counters, {
                      'fooPreEnter': 1,
                      'fooPreLeave': 0,
                      'fooEnter': 1,
                      'fooLeave': 0,
                      'barPreEnter': 1,
                      'barPreLeave': 1,
                      'barEnter': 1,
                      'barLeave': 1,
                      'bazPreEnter': 1,
                      'bazPreLeave': 0,
                      'bazEnter': 1,
                      'bazLeave': 0
                    });
                  }))))
          .then(expectAsync1((_) =>
              router.route('/foo/baz?baz.blah=meme').then(expectAsync1((_) {
                expect(counters, {
                  'fooPreEnter': 1,
                  'fooPreLeave': 0,
                  'fooEnter': 1,
                  'fooLeave': 0,
                  'barPreEnter': 1,
                  'barPreLeave': 1,
                  'barEnter': 1,
                  'barLeave': 1,
                  'bazPreEnter': 2,
                  'bazPreLeave': 1,
                  'bazEnter': 2,
                  'bazLeave': 1
                });
              }))));
    });

    test('should leave starting from child to parent', () {
      var log = [];
      void loggingLeaveHandler(RouteLeaveEvent r) {
        log.add(r.route.name);
      }

      ;

      var router = Router();
      router.root
        ..addRoute(
            path: '/foo',
            name: 'foo',
            leave: loggingLeaveHandler,
            mount: (Route route) => route
              ..addRoute(
                  path: '/bar',
                  name: 'bar',
                  leave: loggingLeaveHandler,
                  mount: (Route route) => route
                    ..addRoute(
                        path: '/baz',
                        name: 'baz',
                        leave: loggingLeaveHandler)));

      router.route('/foo/bar/baz').then(expectAsync1((_) {
        expect(log, []);

        router.route('').then(expectAsync1((_) {
          expect(log, ['baz', 'bar', 'foo']);
        }));
      }));
    });

    test('should leave active child route when routed to parent route only',
        () {
      var router = Router();
      router.root
        ..addRoute(
            path: '/foo',
            name: 'foo',
            mount: (Route route) => route..addRoute(path: '/bar', name: 'bar'));

      return router.route('/foo/bar').then((_) {
        expect(router.activePath.map((r) => r.name), ['foo', 'bar']);
        return router.route('/foo').then((_) {
          expect(router.activePath.map((r) => r.name), ['foo']);
        });
      });
    });

    void _testAllowLeave(bool allowLeave) {
      var completer = Completer<bool>();
      bool barEntered = false;
      bool bazEntered = false;

      var router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            mount: (Route child) => child
              ..addRoute(
                  name: 'bar',
                  path: '/bar',
                  enter: (RouteEnterEvent e) => barEntered = true,
                  preLeave: (RoutePreLeaveEvent e) =>
                      e.allowLeave(completer.future))
              ..addRoute(
                  name: 'baz',
                  path: '/baz',
                  enter: (RouteEnterEvent e) => bazEntered = true));

      router.route('/foo/bar').then(expectAsync1((_) {
        expect(barEntered, true);
        expect(bazEntered, false);
        router.route('/foo/baz').then(expectAsync1((_) {
          expect(bazEntered, allowLeave);
        }));
        completer.complete(allowLeave);
      }));
    }

    test('should allow navigation', () {
      _testAllowLeave(true);
    });

    test('should veto navigation', () {
      _testAllowLeave(false);
    });
  });

  group('preEnter', () {
    void _testAllowEnter(bool allowEnter) {
      var completer = Completer<bool>();
      bool barEntered = false;

      var router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            mount: (Route child) => child
              ..addRoute(
                  name: 'bar',
                  path: '/bar',
                  enter: (RouteEnterEvent e) => barEntered = true,
                  preEnter: (RoutePreEnterEvent e) =>
                      e.allowEnter(completer.future)));

      router.route('/foo/bar').then(expectAsync1((_) {
        expect(barEntered, allowEnter);
      }));
      completer.complete(allowEnter);
    }

    test('should allow navigation', () {
      _testAllowEnter(true);
    });

    test('should veto navigation', () {
      _testAllowEnter(false);
    });

    test(
        'should leave on parameters changes when dontLeaveOnParamChanges is false (default)',
        () {
      var counters = <String, int>{
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0
      };
      var router = Router();
      router.root
        ..addRoute(
            path: r'/foo/:param',
            name: 'foo',
            preEnter: (_) => counters['fooPreEnter']++,
            preLeave: (_) => counters['fooPreLeave']++,
            enter: (_) => counters['fooEnter']++,
            leave: (_) => counters['fooLeave']++)
        ..addRoute(
            path: '/bar',
            name: 'bar',
            preEnter: (_) => counters['barPreEnter']++,
            preLeave: (_) => counters['barPreLeave']++,
            enter: (_) => counters['barEnter']++,
            leave: (_) => counters['barLeave']++);

      expect(counters, {
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0
      });

      expect(router.findRoute('foo').dontLeaveOnParamChanges, false);

      router.route('/foo/bar').then(expectAsync1((_) {
        expect(counters, {
          'fooPreEnter': 1, // +1
          'fooPreLeave': 0,
          'fooEnter': 1, // +1
          'fooLeave': 0,
          'barPreEnter': 0,
          'barPreLeave': 0,
          'barEnter': 0,
          'barLeave': 0
        });

        router.route('/foo/bar').then(expectAsync1((_) {
          expect(counters, {
            'fooPreEnter': 1,
            'fooPreLeave': 0,
            'fooEnter': 1,
            'fooLeave': 0,
            'barPreEnter': 0,
            'barPreLeave': 0,
            'barEnter': 0,
            'barLeave': 0
          });

          router.route('/foo/baz').then(expectAsync1((_) {
            expect(counters, {
              'fooPreEnter': 2, // +1
              'fooPreLeave': 1, // +1
              'fooEnter': 2, // +1
              'fooLeave': 1, // +1
              'barPreEnter': 0,
              'barPreLeave': 0,
              'barEnter': 0,
              'barLeave': 0
            });

            router.route('/bar').then(expectAsync1((_) {
              expect(counters, {
                'fooPreEnter': 2,
                'fooPreLeave': 2, // +1
                'fooEnter': 2,
                'fooLeave': 2, // +1
                'barPreEnter': 1, // +1
                'barPreLeave': 0,
                'barEnter': 1, // +1
                'barLeave': 0
              });
            }));
          }));
        }));
      }));
    });

    test(
        'should not leave on parameter changes when dontLeaveOnParamChanges is true',
        () {
      var counters = <String, int>{
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0
      };
      var router = Router();
      router.root
        ..addRoute(
            path: r'/foo/:param',
            name: 'foo',
            preEnter: (_) => counters['fooPreEnter']++,
            preLeave: (_) => counters['fooPreLeave']++,
            enter: (_) => counters['fooEnter']++,
            leave: (_) => counters['fooLeave']++,
            dontLeaveOnParamChanges: true)
        ..addRoute(
            path: '/bar',
            name: 'bar',
            preEnter: (_) => counters['barPreEnter']++,
            preLeave: (_) => counters['barPreLeave']++,
            enter: (_) => counters['barEnter']++,
            leave: (_) => counters['barLeave']++);

      expect(counters, {
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0
      });

      router.route('/foo/bar').then(expectAsync1((_) {
        expect(counters, {
          'fooPreEnter': 1, // +1
          'fooPreLeave': 0,
          'fooEnter': 1, // +1
          'fooLeave': 0,
          'barPreEnter': 0,
          'barPreLeave': 0,
          'barEnter': 0,
          'barLeave': 0
        });

        router.route('/foo/bar').then(expectAsync1((_) {
          expect(counters, {
            'fooPreEnter': 1,
            'fooPreLeave': 0,
            'fooEnter': 1,
            'fooLeave': 0,
            'barPreEnter': 0,
            'barPreLeave': 0,
            'barEnter': 0,
            'barLeave': 0
          });

          router.route('/foo/baz').then(expectAsync1((_) {
            expect(counters, {
              'fooPreEnter': 2, // +1
              'fooPreLeave': 0,
              'fooEnter': 2, // +1
              'fooLeave': 0,
              'barPreEnter': 0,
              'barPreLeave': 0,
              'barEnter': 0,
              'barLeave': 0
            });

            router.route('/bar').then(expectAsync1((_) {
              expect(counters, {
                'fooPreEnter': 2,
                'fooPreLeave': 1, // +1
                'fooEnter': 2,
                'fooLeave': 1, // +1
                'barPreEnter': 1, // +1
                'barPreLeave': 0,
                'barEnter': 1, // +1
                'barLeave': 0
              });
            }));
          }));
        }));
      }));
    });

    test('should not leave leaving when on preEnter fails', () {
      var counters = <String, int>{
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0
      };
      var router = Router();
      router.root
        ..addRoute(
            path: r'/foo',
            name: 'foo',
            preEnter: (_) => counters['fooPreEnter']++,
            preLeave: (_) => counters['fooPreLeave']++,
            enter: (_) => counters['fooEnter']++,
            leave: (_) => counters['fooLeave']++)
        ..addRoute(
            path: '/bar',
            name: 'bar',
            preEnter: (RoutePreEnterEvent e) {
              counters['barPreEnter']++;
              e.allowEnter(Future<bool>.value(false));
            },
            preLeave: (_) => counters['barPreLeave']++,
            enter: (_) => counters['barEnter']++,
            leave: (_) => counters['barLeave']++);

      expect(counters, {
        'fooPreEnter': 0,
        'fooPreLeave': 0,
        'fooEnter': 0,
        'fooLeave': 0,
        'barPreEnter': 0,
        'barPreLeave': 0,
        'barEnter': 0,
        'barLeave': 0
      });

      router.route('/foo').then(expectAsync1((_) {
        expect(counters, {
          'fooPreEnter': 1, // +1
          'fooPreLeave': 0,
          'fooEnter': 1, // +1
          'fooLeave': 0,
          'barPreEnter': 0,
          'barPreLeave': 0,
          'barEnter': 0,
          'barLeave': 0
        });

        router.route('/bar').then(expectAsync1((_) {
          expect(counters, {
            'fooPreEnter': 1,
            'fooPreLeave': 1, // +1
            'fooEnter': 1,
            'fooLeave': 0, // can't leave
            'barPreEnter': 1, // +1, enter but don't proceed
            'barPreLeave': 0,
            'barEnter': 0,
            'barLeave': 0
          });
        }));
      }));
    });
  });

  group('Default route', () {
    void _testHeadTail(String path, String expectFoo, String expectBar) {
      var router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            defaultRoute: true,
            enter: expectAsync1((RouteEvent e) {
              expect(e.path, expectFoo);
            }),
            mount: (child) => child
              ..addRoute(
                  name: 'bar',
                  path: '/bar',
                  defaultRoute: true,
                  enter: expectAsync1(
                      (RouteEvent e) => expect(e.path, expectBar))));

      router.route(path);
    }

    test('should calculate head/tail of empty route', () {
      _testHeadTail('', '', '');
    });

    test('should calculate head/tail of partial route', () {
      _testHeadTail('/foo', '/foo', '');
    });

    test('should calculate head/tail of a route', () {
      _testHeadTail('/foo/bar', '/foo', '/bar');
    });

    test('should calculate head/tail of an invalid parent route', () {
      _testHeadTail('/garbage/bar', '', '');
    });

    test('should calculate head/tail of an invalid child route', () {
      _testHeadTail('/foo/garbage', '/foo', '');
    });

    test('should follow default routes', () {
      var counters = <String, int>{
        'list_entered': 0,
        'article_123_entered': 0,
        'article_123_view_entered': 0,
        'article_123_edit_entered': 0
      };

      var router = Router();
      router.root
        ..addRoute(
            name: 'articles',
            path: '/articles',
            defaultRoute: true,
            enter: (_) => counters['list_entered']++)
        ..addRoute(
            name: 'article',
            path: '/article/123',
            enter: (_) => counters['article_123_entered']++,
            mount: (Route child) => child
              ..addRoute(
                  name: 'viewArticles',
                  path: '/view',
                  defaultRoute: true,
                  enter: (_) => counters['article_123_view_entered']++)
              ..addRoute(
                  name: 'editArticles',
                  path: '/edit',
                  enter: (_) => counters['article_123_edit_entered']++));

      return router.route('').then((_) {
        expect(counters, {
          'list_entered': 1, // default to list
          'article_123_entered': 0,
          'article_123_view_entered': 0,
          'article_123_edit_entered': 0
        });
        return router.route('/articles').then((_) {
          expect(counters, {
            'list_entered': 2,
            'article_123_entered': 0,
            'article_123_view_entered': 0,
            'article_123_edit_entered': 0
          });
          return router.route('/article/123').then((_) {
            expect(counters, {
              'list_entered': 2,
              'article_123_entered': 1,
              'article_123_view_entered': 1, // default to view
              'article_123_edit_entered': 0
            });
            return router.route('/article/123/view').then((_) {
              expect(counters, {
                'list_entered': 2,
                'article_123_entered': 1,
                'article_123_view_entered': 2,
                'article_123_edit_entered': 0
              });
              return router.route('/article/123/edit').then((_) {
                expect(counters, {
                  'list_entered': 2,
                  'article_123_entered': 1,
                  'article_123_view_entered': 2,
                  'article_123_edit_entered': 1
                });
              });
            });
          });
        });
      });
    });
  });

  group('go', () {
    tearDown(() {
      resetMockitoState();
    });

    test('should use location.assign/.replace when useFragment=true', () {
      var mockWindow = MockWindow();
      var router = Router(useFragment: true, windowImpl: mockWindow);
      router.root.addRoute(name: 'articles', path: '/articles');

      router.go('articles', {}).then(expectAsync1((_) {
        var mockLocation = mockWindow.location;

        var result = verify(mockLocation.assign(captureAny));
        result.called(1);
        expect(result.captured.first, '#/articles');
        verifyNever(mockLocation.replace(any));

        router.go('articles', {}, replace: true).then(expectAsync1((_) {
          var result = verify(mockLocation.replace(captureAny));
          result.called(1);
          expect(result.captured.first, '#/articles');
          verifyNever(mockLocation.assign(any));
        }));
      }));
    });

    test('should use history.push/.replaceState when useFragment=false', () {
      var mockWindow = MockWindow();
      var router = Router(useFragment: false, windowImpl: mockWindow);
      router.root.addRoute(name: 'articles', path: '/articles');
      when((mockWindow.document as HtmlDocument).title)
          .thenReturn('page title');

      router.go('articles', {}).then(expectAsync1((_) {
        var mockHistory = mockWindow.history;

        var result =
            verify(mockHistory.pushState(captureAny, captureAny, captureAny));
        result.called(1);
        expect(result.captured, [null, 'page title', '/articles']);
        verifyNever(mockHistory.replaceState(any, any, any));

        router.go('articles', {}, replace: true).then(expectAsync1((_) {
          var result = verify(
              mockHistory.replaceState(captureAny, captureAny, captureAny));
          result.called(1);
          expect(result.captured, [null, 'page title', '/articles']);
          verifyNever(mockHistory.pushState(any, any, any));
        }));
      }));
    });

    test('should encode query parameters in the URL', () {
      var mockWindow = MockWindow();
      var router = Router(useFragment: false, windowImpl: mockWindow);
      router.root.addRoute(name: 'articles', path: '/articles');
      when((mockWindow.document as HtmlDocument).title)
          .thenReturn('page title');

      var queryParams = {'foo': 'foo bar', 'bar': '%baz+aux'};
      router
          .go('articles', {}, queryParameters: queryParams)
          .then(expectAsync1((_) {
        var mockHistory = mockWindow.history;

        var result =
            verify(mockHistory.pushState(captureAny, captureAny, captureAny));
        result.called(1);
        expect(result.captured,
            [null, 'page title', '/articles?foo=foo%20bar&bar=%25baz%2Baux']);
        verifyNever(mockHistory.replaceState(any, any, any));
      }));
    });

    test('should work with hierarchical go', () {
      var mockWindow = MockWindow();
      when((mockWindow.document as HtmlDocument).title)
          .thenReturn('page title');
      var router = Router(windowImpl: mockWindow);
      router.root
        ..addRoute(
            name: 'a',
            path: '/:foo',
            mount: (child) => child..addRoute(name: 'b', path: '/:bar'));

      var routeA = router.root.findRoute('a');

      router.go('a.b', {}).then(expectAsync1((_) {
        var mockHistory = mockWindow.history;

        var result =
            verify(mockHistory.pushState(captureAny, captureAny, captureAny));
        result.called(1);
        expect(result.captured, [null, 'page title', '/null/null']);

        router.go('a.b', {'foo': 'aaaa', 'bar': 'bbbb'}).then(expectAsync1((_) {
          var result =
              verify(mockHistory.pushState(captureAny, captureAny, captureAny));
          result.called(1);
          expect(result.captured, [null, 'page title', '/aaaa/bbbb']);

          router
              .go('b', {'bar': 'bbbb'}, startingFrom: routeA)
              .then(expectAsync1((_) {
            var result = verify(
                mockHistory.pushState(captureAny, captureAny, captureAny));
            // Note: These were cumulative with mock but get reset with each
            // call to mockito.verify(), so 3 became 1 here.
            result.called(1);
            expect(result.captured, [null, 'page title', '/aaaa/bbbb']);
          }));
        }));
      }));
    });

    test('should attempt to reverse default routes', () {
      var counters = <String, int>{'aEnter': 0, 'bEnter': 0};

      var mockWindow = MockWindow();

      when((mockWindow.document as HtmlDocument).title)
          .thenReturn('page title');
      var router = Router(windowImpl: mockWindow);
      router.root
        ..addRoute(
            name: 'a',
            defaultRoute: true,
            path: '/:foo',
            enter: (_) => counters['aEnter']++,
            mount: (child) => child
              ..addRoute(
                  name: 'b',
                  defaultRoute: true,
                  path: '/:bar',
                  enter: (_) => counters['bEnter']++));

      expect(counters, {'aEnter': 0, 'bEnter': 0});

      return router.route('').then((_) {
        expect(counters, {'aEnter': 1, 'bEnter': 1});

        var routeA = router.root.findRoute('a');
        return router.go('b', {'bar': 'bbb'}, startingFrom: routeA).then((_) {
          var mockHistory = mockWindow.history;

          var result =
              verify(mockHistory.pushState(captureAny, captureAny, captureAny));
          result.called(1);
          expect(result.captured, [null, 'page title', '/null/bbb']);
        });
      });
    });

    test('should force reload already active routes', () {
      var counters = <String, int>{'aEnter': 0, 'bEnter': 0};

      var mockWindow = MockWindow();
      when((mockWindow.document as HtmlDocument).title)
          .thenReturn('page title');
      var router = Router(windowImpl: mockWindow);
      router.root
        ..addRoute(
            name: 'a',
            path: '/foo',
            enter: (_) => counters['aEnter']++,
            mount: (child) => child
              ..addRoute(
                  name: 'b', path: '/bar', enter: (_) => counters['bEnter']++));

      expect(counters, {'aEnter': 0, 'bEnter': 0});

      return router.go('a.b', {}).then((_) {
        expect(counters, {'aEnter': 1, 'bEnter': 1});
        return router.go('a.b', {}).then((_) {
          // didn't force reload, so should not change
          expect(counters, {'aEnter': 1, 'bEnter': 1});
          return router.go('a.b', {}, forceReload: true).then((_) {
            expect(counters, {'aEnter': 2, 'bEnter': 2});
          });
        });
      });
    });

    test('should update page title if the title property is set', () {
      var mockWindow = MockWindow();
      var router = Router(useFragment: false, windowImpl: mockWindow);
      router.root.addRoute(name: 'foo', path: '/foo', pageTitle: 'Foo');

      router.go('foo', {}).then(expectAsync1((_) {
        var mockHistory = mockWindow.history;
        verify((mockWindow.document as HtmlDocument).title = any).called(1);
        verify(mockHistory.pushState(null, 'Foo', '/foo')).called(1);
      }));
    });

    test('should not change page title if the title property is not set', () {
      var mockWindow = MockWindow();
      when((mockWindow.document as HtmlDocument).title)
          .thenReturn('page title');
      var router = Router(useFragment: false, windowImpl: mockWindow);
      router.root.addRoute(name: 'foo', path: '/foo');

      router.go('foo', {}).then(expectAsync1((_) {
        var mockHistory = mockWindow.history;
        verify(mockHistory.pushState(null, 'page title', '/foo')).called(1);
      }));
    });
  });

  group('url', () {
    test('should reconstruct url', () {
      var mockWindow = MockWindow();
      var router = Router(windowImpl: mockWindow);
      router.root
        ..addRoute(
            name: 'a',
            defaultRoute: true,
            path: '/:foo',
            mount: (child) =>
                child..addRoute(name: 'b', defaultRoute: true, path: '/:bar'));

      var routeA = router.root.findRoute('a');

      return router.route('').then((_) {
        expect(router.url('a.b'), '/null/null');
        expect(router.url('a.b', parameters: {'foo': 'aaa'}), '/aaa/null');
        expect(
            router.url('b', parameters: {'bar': 'bbb'}, startingFrom: routeA),
            '/null/bbb');

        return router.route('/foo/bar').then((_) {
          expect(router.url('a.b'), '/foo/bar');
          expect(router.url('a.b', parameters: {'foo': 'aaa'}), '/aaa/bar');
          expect(
              router.url('b', parameters: {'bar': 'bbb'}, startingFrom: routeA),
              '/foo/bbb');
          expect(
              router.url('b',
                  parameters: {'foo': 'aaa', 'bar': 'bbb'},
                  startingFrom: routeA),
              '/foo/bbb');

          expect(
              router.url('b',
                  parameters: {'bar': 'bbb'},
                  queryParameters: {'param1': 'val1'},
                  startingFrom: routeA),
              '/foo/bbb?param1=val1');
        });
      });
    });
  });

  group('findRoute', () {
    test('should return correct routes', () {
      Route routeFoo, routeBar, routeBaz, routeQux, routeAux;

      var router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/:foo',
            mount: (child) => routeFoo = child
              ..addRoute(
                  name: 'bar',
                  path: '/:bar',
                  mount: (child) => routeBar = child
                    ..addRoute(
                        name: 'baz',
                        path: '/:baz',
                        mount: (child) => routeBaz = child))
              ..addRoute(
                  name: 'qux',
                  path: '/:qux',
                  mount: (child) => routeQux = child
                    ..addRoute(
                        name: 'aux',
                        path: '/:aux',
                        mount: (child) => routeAux = child)));

      expect(router.root.findRoute('foo'), same(routeFoo));
      expect(router.root.findRoute('foo.bar'), same(routeBar));
      expect(routeFoo.findRoute('bar'), same(routeBar));
      expect(router.root.findRoute('foo.bar.baz'), same(routeBaz));
      expect(router.root.findRoute('foo.qux'), same(routeQux));
      expect(router.root.findRoute('foo.qux.aux'), same(routeAux));
      expect(routeQux.findRoute('aux'), same(routeAux));
      expect(routeFoo.findRoute('qux.aux'), same(routeAux));

      expect(router.root.findRoute('baz'), isNull);
      expect(router.root.findRoute('foo.baz'), isNull);
    });
  });

  group('route', () {
    group('query params', () {
      test('should parse query', () {
        var router = Router();
        router.root
          ..addRoute(
              name: 'foo',
              path: '/:foo',
              enter: expectAsync1((RouteEvent e) {
                expect(e.parameters, {
                  'foo': '123',
                });
                expect(e.queryParameters, {'a': 'b', 'b': '', 'c': 'foo bar'});
              }));

        router.route('/123?a=b&b=&c=foo%20bar');
      });

      test('should not reload when unwatched query param changes', () {
        var router = Router();
        var counters = {
          'fooLeave': 0,
          'fooEnter': 0,
        };
        router.root
          ..addRoute(
              name: 'foo',
              path: '/:foo',
              watchQueryParameters: ['bar'],
              leave: (_) => counters['fooLeave']++,
              enter: (_) => counters['fooEnter']++);

        return router.route('/123').then((_) {
          expect(counters, {
            'fooLeave': 0,
            'fooEnter': 1,
          });
          return router.route('/123?foo=bar').then((_) {
            expect(counters, {
              'fooLeave': 0,
              'fooEnter': 1,
            });
          });
        });
      });

      test('should reload when watched query param changes', () {
        var router = Router();
        var counters = {
          'fooLeave': 0,
          'fooEnter': 0,
        };
        router.root
          ..addRoute(
              name: 'foo',
              path: '/:foo',
              watchQueryParameters: ['foo'],
              leave: (_) => counters['fooLeave']++,
              enter: (_) => counters['fooEnter']++);

        return router.route('/123').then((_) {
          expect(counters, {
            'fooLeave': 0,
            'fooEnter': 1,
          });
          return router.route('/123?foo=bar').then((_) {
            expect(counters, {
              'fooLeave': 1,
              'fooEnter': 2,
            });
          });
        });
      });

      test('should match pattern for watched query params', () {
        var router = Router();
        var counters = {
          'fooLeave': 0,
          'fooEnter': 0,
        };
        router.root
          ..addRoute(
              name: 'foo',
              path: '/:foo',
              watchQueryParameters: [RegExp(r'^foo$')],
              leave: (_) => counters['fooLeave']++,
              enter: (_) => counters['fooEnter']++);

        return router.route('/123').then((_) {
          expect(counters, {
            'fooLeave': 0,
            'fooEnter': 1,
          });
          return router.route('/123?foo=bar').then((_) {
            expect(counters, {
              'fooLeave': 1,
              'fooEnter': 2,
            });
          });
        });
      });
    });

    group('isActive', () {
      test('should currectly identify active/inactive routes', () {
        var router = Router();
        router.root
          ..addRoute(
              name: 'foo',
              path: '/foo',
              mount: (child) => child
                ..addRoute(
                    name: 'bar',
                    path: '/bar',
                    mount: (child) => child
                      ..addRoute(
                          name: 'baz', path: '/baz', mount: (child) => child))
                ..addRoute(
                    name: 'qux',
                    path: '/qux',
                    mount: (child) => child
                      ..addRoute(
                          name: 'aux', path: '/aux', mount: (child) => child)));

        expect(r(router, 'foo').isActive, false);
        expect(r(router, 'foo.bar').isActive, false);
        expect(r(router, 'foo.bar.baz').isActive, false);
        expect(r(router, 'foo.qux').isActive, false);

        return router.route('/foo').then((_) {
          expect(r(router, 'foo').isActive, true);
          expect(r(router, 'foo.bar').isActive, false);
          expect(r(router, 'foo.bar.baz').isActive, false);
          expect(r(router, 'foo.qux').isActive, false);

          return router.route('/foo/qux').then((_) {
            expect(r(router, 'foo').isActive, true);
            expect(r(router, 'foo.bar').isActive, false);
            expect(r(router, 'foo.bar.baz').isActive, false);
            expect(r(router, 'foo.qux').isActive, true);

            return router.route('/foo/bar/baz').then((_) {
              expect(r(router, 'foo').isActive, true);
              expect(r(router, 'foo.bar').isActive, true);
              expect(r(router, 'foo.bar.baz').isActive, true);
              expect(r(router, 'foo.qux').isActive, false);
            });
          });
        });
      });
    });

    group('parameters', () {
      test('should return path parameters for routes', () {
        var router = Router();
        router.root
          ..addRoute(
              name: 'foo',
              path: '/:foo',
              mount: (child) => child
                ..addRoute(
                    name: 'bar',
                    path: '/:bar',
                    mount: (child) => child
                      ..addRoute(
                          name: 'baz',
                          path: '/:baz',
                          mount: (child) => child)));

        expect(r(router, 'foo').parameters, isNull);
        expect(r(router, 'foo.bar').parameters, isNull);
        expect(r(router, 'foo.bar.baz').parameters, isNull);

        return router.route('/aaa').then((_) {
          expect(r(router, 'foo').parameters, {'foo': 'aaa'});
          expect(r(router, 'foo.bar').parameters, isNull);
          expect(r(router, 'foo.bar.baz').parameters, isNull);

          return router.route('/aaa/bbb').then((_) {
            expect(r(router, 'foo').parameters, {'foo': 'aaa'});
            expect(r(router, 'foo.bar').parameters, {'bar': 'bbb'});
            expect(r(router, 'foo.bar.baz').parameters, isNull);

            return router.route('/aaa/bbb/ccc').then((_) {
              expect(r(router, 'foo').parameters, {'foo': 'aaa'});
              expect(r(router, 'foo.bar').parameters, {'bar': 'bbb'});
              expect(r(router, 'foo.bar.baz').parameters, {'baz': 'ccc'});
            });
          });
        });
      });
    });
  });

  group('activePath', () {
    test('should currectly identify active path', () {
      var router = Router();
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            mount: (child) => child
              ..addRoute(
                  name: 'bar',
                  path: '/bar',
                  mount: (child) => child
                    ..addRoute(
                        name: 'baz', path: '/baz', mount: (child) => child))
              ..addRoute(
                  name: 'qux',
                  path: '/qux',
                  mount: (child) => child
                    ..addRoute(
                        name: 'aux', path: '/aux', mount: (child) => child)));

      var strPath =
          (List<Route> path) => path.map((Route r) => r.name).join('.');

      expect(strPath(router.activePath), '');

      return router.route('/foo').then((_) {
        expect(strPath(router.activePath), 'foo');

        return router.route('/foo/qux').then((_) {
          expect(strPath(router.activePath), 'foo.qux');

          return router.route('/foo/bar/baz').then((_) {
            expect(strPath(router.activePath), 'foo.bar.baz');
          });
        });
      });
    });

    test('should currectly identify active path after relative go', () {
      var mockWindow = MockWindow();
      var router = Router(windowImpl: mockWindow);
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            mount: (child) => child
              ..addRoute(
                  name: 'bar',
                  path: '/bar',
                  mount: (child) => child
                    ..addRoute(
                        name: 'baz', path: '/baz', mount: (child) => child))
              ..addRoute(
                  name: 'qux',
                  path: '/qux',
                  mount: (child) => child
                    ..addRoute(
                        name: 'aux', path: '/aux', mount: (child) => child)));

      var strPath =
          (List<Route> path) => path.map((Route r) => r.name).join('.');

      expect(strPath(router.activePath), '');

      return router.route('/foo').then((_) {
        expect(strPath(router.activePath), 'foo');

        var foo = router.findRoute('foo');
        return router.go('bar', {}, startingFrom: foo).then((_) {
          expect(strPath(router.activePath), 'foo.bar');
        });
      });
    });

    test(
        'should currectly identify active path after relative go from deeper active path',
        () {
      var mockWindow = MockWindow();
      var router = Router(windowImpl: mockWindow);
      router.root
        ..addRoute(
            name: 'foo',
            path: '/foo',
            mount: (child) => child
              ..addRoute(
                  name: 'bar',
                  path: '/bar',
                  mount: (child) => child
                    ..addRoute(
                        name: 'baz', path: '/baz', mount: (child) => child))
              ..addRoute(
                  name: 'qux',
                  path: '/qux',
                  mount: (child) => child
                    ..addRoute(
                        name: 'aux', path: '/aux', mount: (child) => child)));

      var strPath =
          (List<Route> path) => path.map((Route r) => r.name).join('.');

      expect(strPath(router.activePath), '');

      return router.route('/foo/qux/aux').then((_) {
        expect(strPath(router.activePath), 'foo.qux.aux');

        var foo = router.findRoute('foo');
        return router.go('bar', {}, startingFrom: foo).then((_) {
          expect(strPath(router.activePath), 'foo.bar');
        });
      });
    });
  });

  group('listen', () {
    group('fragment', () {
      test('shoud route current hash on listen', () {
        var mockWindow = MockWindow();
        var mockHashChangeController = StreamController<Event>(sync: true);

        when(mockWindow.onHashChange)
            .thenAnswer((_) => mockHashChangeController.stream);
        when(mockWindow.location.hash).thenReturn('#/foo');
        var router = Router(useFragment: true, windowImpl: mockWindow);
        router.root.addRoute(name: 'foo', path: '/foo');
        router.onRouteStart.listen(expectAsync1((RouteStartEvent start) {
          start.completed.then(expectAsync1((_) {
            expect(router.findRoute('foo').isActive, isTrue);
          }));
        }, count: 1));
        router.listen(ignoreClick: true);
      });
    });

    group('pushState', () {
      testInit(mockWindow, [count = 1]) {
        when(mockWindow.location.hash).thenReturn('');
        when(mockWindow.location.pathname).thenReturn('/hello');
        when(mockWindow.location.search).thenReturn('?foo=bar&baz=bat');
        var router = Router(useFragment: false, windowImpl: mockWindow);
        router.root.addRoute(name: 'hello', path: '/hello');
        router.onRouteStart.listen(expectAsync1((RouteStartEvent start) {
          start.completed.then(expectAsync1((_) {
            expect(router.findRoute('hello').isActive, isTrue);
            expect(router.findRoute('hello').queryParameters['baz'], 'bat');
            expect(router.findRoute('hello').queryParameters['foo'], 'bar');
          }));
        }, count: count));
        router.listen(ignoreClick: true);
      }

      test('should route current path on listen with pop', () {
        var mockWindow = MockWindow();
        var mockPopStateController =
            StreamController<PopStateEvent>(sync: true);
        when(mockWindow.onPopState)
            .thenAnswer((_) => mockPopStateController.stream);
        testInit(mockWindow, 2);
        mockPopStateController.add(null);
      });

      test('shoud route current path on listen without pop', () {
        var mockWindow = MockWindow();
        var mockPopStateController =
            StreamController<PopStateEvent>(sync: true);
        when(mockWindow.onPopState)
            .thenAnswer((_) => mockPopStateController.stream);
        testInit(mockWindow);
      });
    });

    group('links', () {
      Element toRemove;

      tearDown(() {
        if (toRemove != null) {
          toRemove.remove();
          toRemove = null;
        }
      });

      test('it should be called if event triggered on anchor element', () {
        AnchorElement anchor = AnchorElement();
        anchor.href = '#test1';
        document.body.append(toRemove = anchor);

        var mockWindow = MockWindow();
        var mockHashChangeController = StreamController<Event>(sync: true);

        when(mockWindow.onHashChange)
            .thenAnswer((_) => mockHashChangeController.stream);
        when(mockWindow.location.hash).thenReturn('#/foo');
        when(mockWindow.location.host).thenReturn(window.location.host);

        var router = Router(useFragment: true, windowImpl: mockWindow);
        router.listen(appRoot: anchor);

        router.onRouteStart.listen(expectAsync1((RouteStartEvent e) {
          expect(e.uri, 'test1');
        }, max: 2));

        anchor.click();
      });

      test(
          'it should be called if event triggered on child of an anchor element',
          () {
        Element anchorChild = DivElement();
        AnchorElement anchor = AnchorElement();
        anchor.href = '#test2';
        anchor.append(anchorChild);
        document.body.append(toRemove = anchor);

        var mockWindow = MockWindow();
        var mockHashChangeController = StreamController<Event>(sync: true);

        when(mockWindow.onHashChange)
            .thenAnswer((_) => mockHashChangeController.stream);
        when(mockWindow.location.hash).thenReturn('#/foo');
        when(mockWindow.location.host).thenReturn(window.location.host);

        var router = Router(useFragment: true, windowImpl: mockWindow);
        router.listen(appRoot: anchor);

        router.onRouteStart.listen(expectAsync1((RouteStartEvent e) {
          expect(e.uri, 'test2');
        }, max: 2));

        anchorChild.click();
      });
    });
  });
}

/// An alias for Router.root.findRoute(path)
r(Router router, String path) => router.root.findRoute(path);
