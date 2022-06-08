// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'elements.dart';

typedef ConsoleFilter = String Function(String line);

class Console {
  /// Our console's ANSI command sequence handler.
  late final AnsiConsoleHandler _ansiConsoleHandler;

  // The duration to wait before adding DOM elements to the document.
  final Duration bufferDuration;

  /// The element to append messages to.
  final DElement element;

  /// A filter function to apply to all messages.
  final ConsoleFilter? filter;

  /// The CSS class name to apply to error messages.
  final String errorClass;

  /// Are we in dark mode (darkpad or dartpad..).
  final bool darkMode;

  final _bufferedOutput = <DivElement>[];

  Console(this.element,
      {this.bufferDuration = const Duration(milliseconds: 32),
      this.filter,
      this.errorClass = 'error-output',
      this.darkMode = true}) {
    _ansiConsoleHandler = AnsiConsoleHandler(darkMode);
  }

  /// Displays console output. Does not clear the console.
  void showOutput(String message, {bool error = false}) {
    final filter = this.filter;
    if (filter != null) {
      message = filter(message);
    }

    final DivElement div;

    // Check message for possible ANSI escape codes.
    final int ansiSeqPos = message.indexOf('\u001B[');
    if (_ansiConsoleHandler.ansiStylesActive || ansiSeqPos != -1) {
      // We either have ansi styles active or there is a possible ansi escape
      // code in this message...
      div = _ansiConsoleHandler.handleAnsiOutput('$message\n', ansiSeqPos);
    } else {
      // Just regular message and no ansi, work as usual..
      div = DivElement()..text = '$message\n';
    }

    // Prevent long lines of text from expanding the console panel.
    div.style.width = '0';

    div.classes.add(error ? errorClass : 'normal');

    // Buffer the console output so that heavy writing to stdout does not
    // starve the DOM thread.
    _bufferedOutput.add(div);
    if (_bufferedOutput.length == 1) {
      Timer(bufferDuration, () {
        element.element.children.addAll(_bufferedOutput);
        // Using scrollIntoView(ScrollAlignment.BOTTOM) causes the parent page
        // to scroll, so set the scrollTop instead.
        final last = element.element.children.last;
        element.element.scrollTop = last.offsetTop;
        _bufferedOutput.clear();
      });
    }
  }

  void clear() {
    element.text = '';
  }
}

class AnsiConsoleHandler {
  /// Dark mode basic ansi colors 0-15.
  static const List<int> darkModeAnsiColors = [
    0x000000, // black
    0xcd3131, // red
    0x0DBC79, // green
    0xe5e510, // yellow
    0x2472c8, // blue
    0xbc3fbc, // magenta
    0x11a8cd, // cyan
    0xe5e5e5, // white
    0x666666, // bright black
    0xf14c4c, // bright red
    0x23d18b, // bright green
    0xf5f543, // bright yellow
    0x3b8eea, // bright blue
    0xd670d6, // bright magenta
    0x29b8db, // bright cyan
    0xe5e5e5, // bright white
  ];

  /// Light mode basic ansi colors 0-15.
  static const List<int> lightModeAnsiColors = [
    0x000000, // black
    0xcd3131, // red
    0x00BC00, // green
    0x949800, // yellow
    0x0451a5, // blue
    0xbc05bc, // magenta
    0x0598bc, // cyan
    0x555555, // white
    0x666666, // bright black
    0xcd3131, // bright red
    0x14CE14, // bright green
    0xb5ba00, // bright yellow
    0x0451a5, // bright blue
    0xbc05bc, // bright magenta
    0x0598bc, // bright cyan
    0xa5a5a5, // bright white
  ];

  /// We set this to [darkModeAnsiColors] or [lightModeAnsiColors] in constructor
  /// depending on [_darkMode].
  late final List<int> _themeModeAnsiColors;

  // Certain ranges that are matched here do not contain real graphics rendition
  // sequences. For the sake of having a simpler expression, they have been
  // included anyway.
  static final RegExp _ansiMatcher = RegExp(
      r'^(?:[34][0-8]|9[0-7]|10[0-7]|[0-9]|2[1-5,7-9]|[34]9|5[8,9]|1[0-9])(?:;[349][0-7]|10[0-7]|[013]|[245]|[34]9)?(?:;[012]?[0-9]?[0-9])*;?m$');

  /// List of currently active Ansi style class names we need will apply to
  /// outgoing text.
  final List<String> ansiStyleClassNames = [];

  /// Do we have any styles to apply to the message ?
  bool ansiStylesActive = false;

  /// Custom Ansi foreground color (or null if none).
  String? _customFgColor;

  /// Custom Ansi background color (or null if none).
  String? _customBgColor;

  /// Custom Ansi underline color (or null if none).
  String? _customUnderlineColor;

  /// Have foreground and background colors been reversed ?
  bool _colorsInverted = false;

  /// Constructor only needs to know if we are in dark mode or not.
  AnsiConsoleHandler(bool darkMode) {
    // Use theme colors from [darkModeAnsiColors] or [lightModeAnsiColors]
    // depending on the setting of [darkMode].
    _themeModeAnsiColors = darkMode ? darkModeAnsiColors : lightModeAnsiColors;
  }

  /// Return a 0x00RRGGBB style color int using passed [red],[green] and
  /// [blue] values.
  static int rgba(int red, int green, int blue) {
    return ((red & 0xFF) << 16) | ((green & 0xFF) << 8) | (blue & 0xFF);
  }

  /// Convert the passed in rgbcolor int value to a CSS 'rgb(r,g,b)' string.
  /// The passed [rgbcolor] int can be null, in which case the fallback
  /// passed in [colorAsString] is returned (this could also be null,
  /// but in cases of swapping foreground/background colors for the inverse
  /// operation is is the previously computed rgb string for the colors).
  static String? makeCSSColorString(int? rgbcolor, String? colorAsString) {
    if (rgbcolor == null) {
      return colorAsString; // Caller may have passed color as string.
    }
    return 'rgb(${(rgbcolor >> 16) & 0xFF},${(rgbcolor >> 8) & 0xFF},${rgbcolor & 0xFF})';
  }

  /// Append the buffer to the specified [div] applying all of the active styles.
  /// The [appendAnsiStyleClassNames] list is applied as class names,
  /// colors set using [fgColor], [bgColor] and [underColor].
  void appendStylizedStringToContainer(
      DivElement div, String buffer, List<String> appendAnsiStyleClassNames,
      [String? fgColor, String? bgColor, String? underColor]) {
    if (buffer.isEmpty) return;

    final SpanElement span = SpanElement()..text = buffer;
    span.classes.addAll(appendAnsiStyleClassNames);
    span.style.color = fgColor;
    span.style.backgroundColor = bgColor;
    if (underColor != null) {
      span.style.textDecorationColor = underColor;
    }
    div.append(span);
  }

  /// Set the member variable corresponding to [colorType] to the css
  /// 'rgb(...)' color string computed from [rgbcolor] (or specified by
  /// [colorAsString]).
  /// [colorType] can be `'foreground'`,`'background'` or `'underline'`
  /// if [rgbcolor] is null then [colorAsString] will attempt to be used, if both
  /// are null then the corresponding color will be reset/cleared.
  void changeSpecifiedCustomColor(String colorType, int? rgbcolor,
      [String? colorAsString]) {
    if (colorType == 'foreground') {
      _customFgColor = makeCSSColorString(rgbcolor, colorAsString);
    } else if (colorType == 'background') {
      _customBgColor = makeCSSColorString(rgbcolor, colorAsString);
    } else if (colorType == 'underline') {
      _customUnderlineColor = makeCSSColorString(rgbcolor, colorAsString);
    }
  }

  /// Swap foregfrouned and background colors.  Used for color inversion.
  /// Caller should check [_colorsInverted] flag to make sure it is appropriate
  /// to turn ON or OFF (if it is already inverted don't call.
  void reverseForegroundAndBackgroundColors() {
    final String? oldFgColor = _customFgColor;
    changeSpecifiedCustomColor('foreground', null,
        _customBgColor); // We have strings already, so pass those.
    changeSpecifiedCustomColor('background', null, oldFgColor);
  }

  /// Calculate the color for [ansiColorNumber] from the color set defined in
  /// the ANSI 8-bit standard.
  /// [ansiColorNumber] should be a number ranging from 16 to 255 otherwise it
  /// is considered an invalid color and `null` will be returned.
  /// Essentialy the value indexes into a 6x6x6 color space.
  /// See  https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit for more info.
  static int? calcAnsi8bitColor(num ansiColorNumber) {
    if (ansiColorNumber >= 16 && ansiColorNumber <= 231) {
      // Converts to one of 216 RGB colors.
      ansiColorNumber -= 16;

      num blue = ansiColorNumber % 6;
      ansiColorNumber = (ansiColorNumber - blue) / 6;
      num green = ansiColorNumber % 6;
      ansiColorNumber = (ansiColorNumber - green) / 6;
      num red = ansiColorNumber;

      // Red, green, blue now range on [0, 5], need to map to [0,255].
      const num convFactor = 255 / 5;
      blue = (blue * convFactor).round();
      green = (green * convFactor).round();
      red = (red * convFactor).round();

      return rgba(red.toInt(), green.toInt(), blue.toInt());
    } else if (ansiColorNumber >= 232 && ansiColorNumber <= 255) {
      // Converts to a grayscale value.
      ansiColorNumber -= 232;
      final int colorLevel = (ansiColorNumber / 23 * 255).round();
      return rgba(colorLevel, colorLevel, colorLevel);
    } else {
      return null;
    }
  }

  /// Calculate and set styling for complicated 24-bit ANSI color codes.
  /// The [styleCodes] contains the list of integer codes that make up the
  /// full ANSI sequence, including the two defining codes and the three
  /// RGB codes.
  /// The [colorType] parameter must be `'foreground'`, `'background'` or
  /// `'underline'` corresponding to which of our custom colors we are setting.
  /// See https://en.wikipedia.org/wiki/ANSI_escape_code#24-bit for more info.
  void set24BitAnsiColor(List<int> styleCodes, String colorType) {
    if (styleCodes.length >= 5 &&
        styleCodes[2] >= 0 &&
        styleCodes[2] <= 255 &&
        styleCodes[3] >= 0 &&
        styleCodes[3] <= 255 &&
        styleCodes[4] >= 0 &&
        styleCodes[4] <= 255) {
      changeSpecifiedCustomColor(
          colorType, rgba(styleCodes[2], styleCodes[3], styleCodes[4]));
    }
  }

  /// Calculate and set styling for basic bright and dark ANSI color codes. Uses
  /// theme colors from [_themeModeAnsiColors].
  /// Automatically distinguishes between foreground and background colors.
  /// (color-clearing codes 39 and 49 are handled by setBasicAnsiFormatters())
  /// The [styleCode] color code on one of the following ranges:
  /// [30-37, 90-97, 40-47, 100-107]. If not on one of these ranges it will be
  /// ignored.
  /// See https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit for
  /// more info.
  void setBasicAnsiColor(int styleCode, {String? overrideColorType}) {
    String? colorType;
    int? colorIndex;

    if (styleCode >= 30 && styleCode <= 37) {
      colorIndex = styleCode - 30;
      colorType = 'foreground';
    } else if (styleCode >= 90 && styleCode <= 97) {
      colorIndex = (styleCode - 90) + 8; // High-intensity (bright).
      colorType = 'foreground';
    } else if (styleCode >= 40 && styleCode <= 47) {
      colorIndex = styleCode - 40;
      colorType = 'background';
    } else if (styleCode >= 100 && styleCode <= 107) {
      colorIndex = (styleCode - 100) + 8; // High-intensity (bright).
      colorType = 'background';
    }
    if (overrideColorType != null) {
      // This is for underline case.
      colorType = overrideColorType;
    }
    if (colorIndex != null && colorType != null) {
      // Look up the color in our theme arrays.
      final int? color =
          (colorIndex >= 0 && colorIndex <= _themeModeAnsiColors.length)
              ? _themeModeAnsiColors[colorIndex]
              : null;
      if (color != null) {
        changeSpecifiedCustomColor(colorType, color);
      }
    }
  }

  /// Used by test harness to get the color for a given ansi code.
  int? getColorFromBasicAnsiColorCode(int styleCode) {
    int? colorIndex;

    if (styleCode >= 30 && styleCode <= 37) {
      colorIndex = styleCode - 30;
    } else if (styleCode >= 90 && styleCode <= 97) {
      colorIndex = (styleCode - 90) + 8; // High-intensity (bright).
    } else if (styleCode >= 40 && styleCode <= 47) {
      colorIndex = styleCode - 40;
    } else if (styleCode >= 100 && styleCode <= 107) {
      colorIndex = (styleCode - 100) + 8; // High-intensity (bright).
    }

    if (colorIndex != null) {
      // Look up the color in our theme arrays.
      final int? color =
          (colorIndex >= 0 && colorIndex <= _themeModeAnsiColors.length)
              ? _themeModeAnsiColors[colorIndex]
              : null;
      return color;
    }
    return null;
  }

  /// Calculate and set styling for advanced 8-bit ANSI color codes.
  /// [styleCodes] is a full list of integer codes that make up the ANSI
  /// sequence, including the two defining codes and the one color code.
  /// [colorType] should be `'foreground'`, `'background'` or `'underline'`
  /// See https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
  /// for more info.
  void set8BitAnsiColor(List<int> styleCodes, String colorType) {
    int colorNumber = styleCodes[2];
    if (colorNumber >= 0 && colorNumber <= 15) {
      // Need to map to one of the four basic color ranges (30-37, 90-97,
      // 40-47, 100-107) depending on if colorType is 'foreground' or
      // 'background'.
      colorNumber += 30;
      if (colorNumber >= 38) {
        // Bright colors.
        colorNumber += 52;
      }
      if (colorType == 'background') {
        colorNumber += 10;
      }
      setBasicAnsiColor(colorNumber, overrideColorType: colorType);
    } else {
      // This is colorNumber in the range 16-255.
      final int? color = calcAnsi8bitColor(colorNumber);
      if (color != null) {
        changeSpecifiedCustomColor(colorType, color);
      }
    }
  }

  /// Accepts a list of basic ANSI style/formatting codes in [styleCodes].
  /// calculates the set basic ANSI formatting. We support most of the defined
  /// codes (reset, bold, italic, underline, double-underline, overline,
  /// strikethrough, superscripts, subscripts, dim, blink, rapid-blink, invert,
  /// hidden, and fonts 1-10).
  /// We also handle normal foreground and background colors, and bright
  /// foreground and background colors codes here.  Not to be used for codes
  /// containing advanced colors.
  /// Will ignore invalid codes.
  /// The ANSI basic styling numbers in [styleCodes] will be applied in order.
  /// New colors and backgrounds clear old ones; new formatting does not.
  /// See https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
  void setBasicAnsiFormatters(final List<int> styleCodes) {
    for (final int code in styleCodes) {
      switch (code) {
        case 0: // reset
          ansiStyleClassNames.clear();
          _customFgColor = _customBgColor = _customUnderlineColor = null;
          break;
        case 1: // bold
          if (!ansiStyleClassNames.contains('ansi-bold')) {
            ansiStyleClassNames.add('ansi-bold');
          }
          break;
        case 2: // dim
          if (!ansiStyleClassNames.contains('ansi-dim')) {
            ansiStyleClassNames.add('ansi-dim');
          }
          break;
        case 3: // italic
          if (!ansiStyleClassNames.contains('ansi-italic')) {
            ansiStyleClassNames.add('ansi-italic');
          }
          break;
        case 4: // underline
          ansiStyleClassNames.removeWhere((style) =>
              (style == 'ansi-underline' || style == 'ansi-double-underline'));
          ansiStyleClassNames.add('ansi-underline');
          break;
        case 5: //blink
          if (!ansiStyleClassNames.contains('ansi-blink')) {
            ansiStyleClassNames.add('ansi-blink');
          }
          break;
        case 6: // rapid blink
          if (!ansiStyleClassNames.contains('ansi-rapid-blink')) {
            ansiStyleClassNames.add('ansi-rapid-blink');
          }
          break;
        case 7: // invert foreground and background
          // We must track if we have inverted colors, subsequent calls are
          // ingored until cleared with 27.
          if (!_colorsInverted) {
            _colorsInverted = true;
            reverseForegroundAndBackgroundColors();
          }
          break;
        case 8: // hidden (but selectable/copy-able)
          if (!ansiStyleClassNames.contains('ansi-hidden')) {
            ansiStyleClassNames.add('ansi-hidden');
          }
          break;
        case 9: // crossed-out
          if (!ansiStyleClassNames.contains('ansi-strike-through')) {
            ansiStyleClassNames.add('ansi-strike-through');
          }
          break;
        case 10: // normal default font
          ansiStyleClassNames
              .removeWhere((style) => style.startsWith('ansi-font'));
          break;
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
        case 16:
        case 17:
        case 18:
        case 19:
        case 20: // font codes (and 20 is 'blackletter' font code)
          ansiStyleClassNames
              .removeWhere((style) => style.startsWith('ansi-font'));
          ansiStyleClassNames.add('ansi-font-${code - 10}');
          break;
        case 21: // make double underline
          ansiStyleClassNames.removeWhere((style) =>
              (style == 'ansi-underline' || style == 'ansi-double-underline'));
          ansiStyleClassNames.add('ansi-double-underline');
          break;
        case 22: // bold and dim Off
          ansiStyleClassNames.removeWhere(
              (style) => style == 'ansi-bold' || style == 'ansi-dim');
          break;
        case 23: // Neither italic or blackletter (font 10)
          ansiStyleClassNames.removeWhere(
              (style) => style == 'ansi-italic' || style == 'ansi-font-10');
          break;
        case 24: // underline off (Neither singly nor doubly underlined)
          ansiStyleClassNames.removeWhere((style) =>
              style == 'ansi-underline' || style == 'ansi-double-underline');
          break;
        case 25: // not blinking
          ansiStyleClassNames.removeWhere(
              (style) => style == 'ansi-blink' || style == 'ansi-rapid-blink');
          break;
        case 27:
          // If we are currently invered then reversed/clear the inversion,
          // otherwise ignored.
          if (_colorsInverted) {
            _colorsInverted = false;
            reverseForegroundAndBackgroundColors();
          }
          break;
        case 28: // reveal - not hidden
          ansiStyleClassNames.remove('ansi-hidden');
          break;
        case 29: // not crossed-out
          ansiStyleClassNames.remove('ansi-strike-through');
          break;
        case 53: // overline
          if (!ansiStyleClassNames.contains('ansi-overline')) {
            ansiStyleClassNames.add('ansi-overline');
          }
          break;
        case 55: // overline off
          ansiStyleClassNames.remove('ansi-overline');
          break;
        case 39: // default foreground color
          changeSpecifiedCustomColor('foreground', null);
          break;
        case 49: // default background color
          changeSpecifiedCustomColor('background', null);
          break;
        case 59: // default underline color
          changeSpecifiedCustomColor('underline', null);
          break;
        case 73: // superscript
          ansiStyleClassNames.removeWhere((style) =>
              style == 'ansi-superscript' || style == 'ansi-subscript');
          ansiStyleClassNames.add('ansi-superscript');
          break;
        case 74: // subscript
          ansiStyleClassNames.removeWhere((style) =>
              style == 'ansi-superscript' || style == 'ansi-subscript');
          ansiStyleClassNames.add('ansi-subscript');
          break;
        case 75: // neither superscript or subscript
          ansiStyleClassNames.removeWhere((style) =>
              style == 'ansi-superscript' || style == 'ansi-subscript');
          break;
        default: // default to basic color command
          setBasicAnsiColor(code);
          break;
      }
    }
  }

  /// This handler is called with a [message] and possibly the position of the
  /// first found ANSI escape sequence (ESC+OPENBRACKET) contained in
  /// [posOfFirstFoundESCBracket] (or -1 if no sequence was found in [message]).
  /// If [posOfFirstFoundESCBracket] is -1 (if no escape sequence was found)
  /// then we short circuit and set currentPos to the LENGTH of [message] so we
  /// immediately copy the entire message, style and output it, bypassing
  /// searching the string for ESC sequences.
  /// (This happpens when [ansiStylesActive] is true so we have active ansi
  /// styles to be applied to this [message]).
  DivElement handleAnsiOutput(
      final String message, final int posOfFirstFoundESCBracket) {
    String buffer = '';
    final int textLength = message.length;
    int currentPos = (posOfFirstFoundESCBracket != -1)
        ? posOfFirstFoundESCBracket
        : textLength;

    final div = DivElement();

    // We may have come in with the location of the first ESC[ sequence, so
    // copy the first part of the string if so.
    if (currentPos > 0) buffer = message.substring(0, currentPos);

    while (currentPos < textLength) {
      bool sequenceFound = false;

      if (message.codeUnitAt(currentPos) == 27 &&
          message[currentPos + 1] == '[') {
        final int startPos = currentPos;
        currentPos += 2; // Ignore 'Esc[' as it's in every sequence.

        String ansiSequence = '';

        while (currentPos < textLength) {
          final char = message[currentPos++];
          ansiSequence += char;
          // Look for a known sequence terminating character.
          if ('ABCDHIJKfhmpsu'.contains(char)) {
            sequenceFound = true;
            break;
          }
        }
        if (sequenceFound) {
          appendStylizedStringToContainer(div, buffer, ansiStyleClassNames,
              _customFgColor, _customBgColor, _customUnderlineColor);
          buffer = '';

          if (_ansiMatcher.hasMatch(ansiSequence)) {
            final List<int> styleCodes = ansiSequence
                .substring(
                    0, ansiSequence.length - 1) // Remove final 'm' character.
                .split(';') // Separate style codes.
                .where((elem) =>
                    elem != '') // Filter empty elems as '34;m' -> ['34', ''].
                .map((elem) => int.tryParse(elem) ?? -1) // Convert to numbers.
                .toList();

            if (styleCodes[0] == 38 ||
                styleCodes[0] == 48 ||
                styleCodes[0] == 58) {
              // Advanced color code - can't be combined with formatting codes
              // like simple colors can.
              // Ignores invalid colors and additional info beyond what is
              // necessary.
              final String colorType = (styleCodes[0] == 38)
                  ? 'foreground'
                  : ((styleCodes[0] == 48) ? 'background' : 'underline');
              if (styleCodes[1] == 5) {
                set8BitAnsiColor(styleCodes, colorType);
              } else if (styleCodes[1] == 2) {
                set24BitAnsiColor(styleCodes, colorType);
              }
            } else {
              setBasicAnsiFormatters(styleCodes);
            }
          } else {
            // Unsupported sequence so simply hide it.
          }
        } else {
          currentPos = startPos;
        }
      }
      if (sequenceFound == false) {
        buffer += message[currentPos];
        currentPos++;
      }
    }
    if (buffer.isNotEmpty) {
      appendStylizedStringToContainer(div, buffer, ansiStyleClassNames,
          _customFgColor, _customBgColor, _customUnderlineColor);
    }

    // Set flag if we have any ansi styles active that we need to be applying
    // to new incoming messages.
    // This allows Console() calls to completely AVOID calling us if there
    // are no ANSI ESC codes present in incoming messages and there are NO
    // active ANSI styles to be applied.
    ansiStylesActive = (ansiStyleClassNames.isNotEmpty ||
        _customFgColor != null ||
        _customBgColor != null ||
        _customUnderlineColor != null);

    return div;
  }
}
