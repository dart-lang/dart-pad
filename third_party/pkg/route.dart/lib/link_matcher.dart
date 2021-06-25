library link_matcher;

import 'dart:html';

// ignore: constant_identifier_names
const _TARGETS = ['_blank', '_parent', '_self', '_top'];

/// RouterLinkMatcher is used to customize [Router] behavior by
/// selecting which [AnchorElement]s to process.
abstract class RouterLinkMatcher {
  bool matches(AnchorElement link);
}

/// A [RouterLinkMatcher] that matches anchor elements which
/// do not have have `_blank`, `_parent`, `_self` or `_top`
/// set as target.
class DefaultRouterLinkMatcher implements RouterLinkMatcher {
  @override
  bool matches(AnchorElement link) => !_TARGETS.contains(link.target);
}
