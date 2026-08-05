import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';

/// A component that groups multiple buttons or items horizontally with cohesive
/// styling and borders.
class ButtonGroup extends StatelessComponent {
  const ButtonGroup({
    required this.children,
    this.classes,
    super.key,
  });

  /// The list of buttons or components aligned in the group.
  final List<Component> children;

  /// Optional extra CSS classes to apply to the button group container.
  final String? classes;

  @override
  Component build(BuildContext context) {
    final classNames = [
      'button-group',
      if (classes case final extraClasses? when extraClasses.isNotEmpty) extraClasses,
    ].join(' ');

    return div(
      classes: classNames,
      children,
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.button-group', [
      css('&').styles(
        display: .inlineFlex,
        margin: .symmetric(horizontal: 4.px),
        border: .all(color: colorBorder, width: 1.px),
        radius: .circular(6.px),
        alignItems: .center,
        backgroundColor: colorContainer,
      ),
      css('& > *, & .icon-button, & .text-button, & .device-dropdown-trigger').styles(
        border: .none,
        radius: .circular(0.px),
      ),
      css(
        '& > *:first-child, & > *:first-child .icon-button, & > *:first-child .text-button, & > *:first-child .device-dropdown-trigger',
      ).styles(
        radius: .only(topLeft: .circular(5.px), bottomLeft: .circular(5.px)),
      ),
      css(
        '& > *:last-child, & > *:last-child .icon-button, & > *:last-child .text-button, & > *:last-child .device-dropdown-trigger',
      ).styles(
        radius: .only(topRight: .circular(5.px), bottomRight: .circular(5.px)),
      ),
      css('& > *:not(:last-child)').styles(
        border: .only(
          right: .solid(color: colorBorder, width: 1.px),
        ),
      ),
      css('& .text-button').styles(
        height: 28.px,
        padding: .symmetric(horizontal: 10.px),
      ),
      css('& .text-button:not(:disabled):hover').styles(
        border: .none,
      ),
    ]),
  ];
}
