library route.url_template_test;

import 'package:test/test.dart';
import 'package:route_hierarchical/url_template.dart';
import 'package:route_hierarchical/url_matcher.dart';

main() {
  group('UrlTemplate', () {
    test('should work with simple templates', () {
      var tmpl = UrlTemplate('/foo/bar:baz/aux');
      expect(tmpl.match('/foo/bar123/aux'),
          UrlMatch('/foo/bar123/aux', '', {'baz': '123'}));

      tmpl = UrlTemplate('/foo/:bar');
      expect(tmpl.match('/foo/123'), UrlMatch('/foo/123', '', {'bar': '123'}));

      tmpl = UrlTemplate('/:foo/bar');
      expect(tmpl.match('/123/bar'), UrlMatch('/123/bar', '', {'foo': '123'}));

      tmpl = UrlTemplate('/user/:userId/article/:articleId/view');
      UrlMatch params =
          tmpl.match('/user/jsmith/article/1234/view/someotherstuff');
      expect(
          params,
          UrlMatch('/user/jsmith/article/1234/view', '/someotherstuff',
              {'userId': 'jsmith', 'articleId': '1234'}));

      params = tmpl.match('/user/jsmith/article/1234/edit');
      expect(params, isNull);

      tmpl = UrlTemplate(r'/foo/:bar$123/aux');
      expect(tmpl.match(r'/foo/123$123/aux'),
          UrlMatch(r'/foo/123$123/aux', '', {'bar': '123'}));
    });

    test('should work with special characters', () {
      var tmpl = UrlTemplate(r'\^\|+[]{}()');
      expect(tmpl.match(r'\^\|+[]{}()'), UrlMatch(r'\^\|+[]{}()', '', {}));

      tmpl = UrlTemplate(r'/:foo/^\|+[]{}()');
      expect(tmpl.match(r'/123/^\|+[]{}()'),
          UrlMatch(r'/123/^\|+[]{}()', '', {'foo': '123'}));
    });

    test('should only match prefix', () {
      var tmpl = UrlTemplate(r'/foo');
      expect(tmpl.match(r'/foo/foo/bar'), UrlMatch(r'/foo', '/foo/bar', {}));
    });

    test('should match without leading slashes', () {
      var tmpl = UrlTemplate(r'foo');
      expect(tmpl.match(r'foo'), UrlMatch(r'foo', '', {}));
    });

    test('should reverse', () {
      var tmpl = UrlTemplate('/:a/:b/:c');
      expect(tmpl.reverse(), '/null/null/null');
      expect(tmpl.reverse(parameters: {'a': 'foo', 'b': 'bar', 'c': 'baz'}),
          '/foo/bar/baz');

      tmpl = UrlTemplate(':a/bar/baz');
      expect(tmpl.reverse(), 'null/bar/baz');
      expect(
          tmpl.reverse(parameters: {
            'a': '/foo',
          }),
          '/foo/bar/baz');

      tmpl = UrlTemplate('/foo/bar/:c');
      expect(tmpl.reverse(), '/foo/bar/null');
      expect(
          tmpl.reverse(parameters: {
            'c': 'baz',
          }),
          '/foo/bar/baz');

      tmpl = UrlTemplate('/foo/bar/:c');
      expect(
          tmpl.reverse(tail: '/tail', parameters: {
            'c': 'baz',
          }),
          '/foo/bar/baz/tail');
    });

    test('should conditionally allow slashes in parameters', () {
      var tmpl = UrlTemplate('/foo/:bar');
      expect(tmpl.match('/foo/123/456'),
          UrlMatch('/foo/123', '/456', {'bar': '123'}));

      tmpl = UrlTemplate('/foo/:bar*');
      expect(tmpl.match('/foo/123/456'),
          UrlMatch('/foo/123/456', '', {'bar*': '123/456'}));

      tmpl = UrlTemplate('/foo/:bar*/baz');
      expect(tmpl.match('/foo/123/456/baz'),
          UrlMatch('/foo/123/456/baz', '', {'bar*': '123/456'}));
    });
  });
}
