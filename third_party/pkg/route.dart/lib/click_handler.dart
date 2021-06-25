library link_handler;

import 'dart:html';

import 'client.dart';
import 'link_matcher.dart';

/// WindowClickHandler can be used as a hook into [Router] to
/// modify behavior right after user clicks on an element, and
/// before the URL in the browser changes.
typedef WindowClickHandler = Function(Event e);

/// This is default behavior used by [Router] to handle clicks on elements.
///
/// The default behavior finds first anchor element. It then uses
/// [RouteLinkMatcher] to decided if it should handle the link or not.
/// See [RouterLinkMatcher] and [DefaultRouterLinkMatcher] for details
/// on deciding if a link should be handled or not.
class DefaultWindowClickHandler {
  final RouterLinkMatcher _linkMatcher;
  final Router _router;
  final String Function(String) _normalizer;
  final Window _window;
  final bool _useFragment;

  DefaultWindowClickHandler(this._linkMatcher, this._router, this._useFragment,
      this._window, this._normalizer);

  void call(Event e) {
    var el = e.target as Element;
    while (el != null && el is! AnchorElement) {
      el = el.parent;
    }
    if (el == null) return;
    assert(el is AnchorElement);
    final anchor = el as AnchorElement;
    if (!_linkMatcher.matches(anchor)) {
      return;
    }
    if (anchor.host == _window.location.host) {
      e.preventDefault();
      if (_useFragment) {
        _router.gotoUrl(_normalizer(anchor.hash));
      } else {
        _router.gotoUrl('${anchor.pathname}${anchor.search}');
      }
    }
  }
}
