// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library dart_pad.console_test;

@TestOn('browser')
import 'dart:html';

import 'package:dart_pad/elements/console.dart';
import 'package:dart_pad/elements/elements.dart';
import 'package:test/test.dart';

void main() => defineTests();

typedef VoidCallback = void Function();
typedef VoidCallbackWithSpan = void Function(SpanElement);


void defineTests() {
  final String rawHtml = '''
      <div id="output-panel">
          <span id="web-output-label" class="view-label absolute">UI Output</span>
            <!-- allow-popups allows plugins like url_launcher to open popups. -->
          <iframe id="frame" sandbox="allow-scripts allow-popups" flex
                  src="scripts/frame_dark.html"></iframe>
          <div id="right-output-panel">
              <span class="view-label">Console</span>
              <div id="right-output-panel-content" class="console custom-scrollbar"></div>
          </div>
          <div id="right-doc-panel">
              <span id="right-doc-label" class="view-label">Documentation</span>
              <div id="right-doc-panel-content" class="documentation custom-scrollbar"></div>
          </div>
      </div>''';
  //Element baseHtml = Element.html(rawHtml);
  //DivElement consoleElement = baseHtml.querySelector('#right-output-panel-content') as DivElement;
  //Console testConsole = Console(DElement(consoleElement),darkMode:true);
  AnsiConsoleHandler ansiConsoleHandler = AnsiConsoleHandler(true);


  setUp(() async {
    print("Setup called in console_test.dart");
    //baseHtml = Element.html(rawHtml);
    //consoleElement = baseHtml.querySelector('#right-output-panel-content') as DivElement;
    //testConsole = Console(DElement(consoleElement),darkMode:true);
    ansiConsoleHandler = AnsiConsoleHandler(true);
  });

  tearDown(() async {
  });


  SpanElement? getSequenceOutput(String sequence) {
      final int ansiSeqPos = sequence.indexOf('\u001B[');
    
    DivElement root = ansiConsoleHandler.handleAnsiOutput( '$sequence\n', ansiSeqPos );

    assert(1==root.children.length);
    var child = root.lastChild!;
    assert(child is SpanElement);
    if (child is SpanElement) {
      return child;
    } else {
      return null; 
    }
  }


  /// 
  /// expect that a given ANSI sequence maintains added content following the ANSI code, and that
  /// the provided {@param expectation} passes.
  /// 
  /// @param sequence The ANSI sequence to verify. The provided sequence should contain ANSI codes
  /// only, and should not include actual text content as it is provided by this function.
  /// @param expectation The function used to verify the output.
  /// 
  void expectSingleSequenceElement( String sequence, VoidCallbackWithSpan expectation ) {
    SpanElement child = getSequenceOutput(sequence + 'content')!;
    assert('content'==child.text);
    expectation(child);
  }


  // 
  // expect that a given DOM element has the custom inline CSS style matching
  // the color value provided.
  // @param element The HTML span element to look at.
  // @param colorType If 'foreground', will check the element's css 'color';
  // if 'background', will check the element's css 'backgroundColor'.
  // if 'underline', will check the elements css 'textDecorationColor'.
  // @param color RGBA object to compare color to. If 'null' or not provided,
  // will expect that no value is set.
  // @param message Optional custom message to pass to expectation.
  // @param colorShouldMatch Optional flag (defaults TO true) which allows caller to indicate that the color SHOULD NOT MATCH
  // (for testing changes to theme colors where we need color to have changed but we don't know exact color it should have
  // changed to (but we do know the color it should NO LONGER BE))
  // 
  void expectInlineColor( SpanElement element, String colorType, int? color, String? message ,[ bool colorShouldMatch=true]) {
    var cssColor='';
    if (color != null) {
      cssColor = AnsiConsoleHandler.makeCSSColorString(color,null)!;
      if (colorType == 'background') {
        final String styleBefore = element.style.backgroundColor;
        element.style.backgroundColor = cssColor;
        expect((styleBefore == element.style.backgroundColor),equals(colorShouldMatch), reason: message ?? 'Incorrect $colorType color style found (found color: $styleBefore, expected $cssColor).');
      } else if (colorType == 'foreground') {
        final String styleBefore = element.style.color;
        element.style.color = cssColor;
        expect((styleBefore == element.style.color),equals(colorShouldMatch), reason: message ?? 'Incorrect $colorType color style found (found color: $styleBefore, expected $cssColor).');
      } else {
        final String styleBefore = element.style.textDecorationColor;
        element.style.textDecorationColor = cssColor;
        expect((styleBefore == element.style.textDecorationColor), equals(colorShouldMatch), reason: message ?? 'Incorrect $colorType color style found (found color: $styleBefore, expected $cssColor).');
      }
    } else {
      if (colorType == 'background') {
        expect(element.style.backgroundColor, isEmpty, reason: message ?? 'Defined $colorType color style found when it should not have been defined');
      } else if (colorType == 'foreground') {
        expect(element.style.color, isEmpty, reason: message ?? 'Defined $colorType color style found when it should not have been defined');
      } else {
        expect(element.style.textDecorationColor,isEmpty, reason: message ?? 'Defined $colorType color style found when it should not have been defined');
      }
    }
  }

  test('appendStylizedStringToContainer', () {
     DivElement root = DivElement();

    expect(root.children.length,equals(0));

    ansiConsoleHandler.appendStylizedStringToContainer(root, 'content1', ['class1', 'class2']);

		ansiConsoleHandler.appendStylizedStringToContainer(root, 'content2', ['class2', 'class3']);

    expect(root.children.length,equals(2)) ;
    var child = root.firstChild!;
    expect((child is SpanElement), equals(true) );
    if (child is SpanElement) {
      expect('content1', child.text);
      expect(child.classes, contains('class1'));
      expect(child.classes, contains('class2'));
    } else {
      expect((child is SpanElement), equals(true) );
    }
    child = root.lastChild!;
    expect((child is SpanElement), equals(true) );
    if (child is SpanElement) {
      expect('content2', child.text);
      expect(child.classes, contains('class2'));
      expect(child.classes, contains('class3'));
    } else {
      expect((child is SpanElement), equals(true) );
    }

  });


  group('Debug - ANSI Handling', () {

    // test

  test('Expected single sequence operation', () {

    // Bold code
	  expectSingleSequenceElement('\u001B[1m', (child) {
      expect(child.classes, contains('ansi-bold'), reason:'Bold formatting not detected after bold ANSI code.');
    });

		// Italic code
		expectSingleSequenceElement('\u001B[3m', (child) {
			expect(child.classes,contains('ansi-italic'), reason:'Italic formatting not detected after italic ANSI code.');
		});

		// Underline code
		expectSingleSequenceElement('\u001B[4m', (child) {
			expect(child.classes, contains('ansi-underline'), reason:'Underline formatting not detected after underline ANSI code.');
		});

    // foreground color codes
    for (int i = 30; i <= 37; i++) {
      final int rgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(i)!;

			// Foreground colour, NO class
			expectSingleSequenceElement('\u001B[${i}m', (child) {
				expect(child.classes, isEmpty, reason:'class found on element after foreground ANSI code #${i}.');
				expectInlineColor(child, 'foreground', rgbcolor, 'ANSI color style $i should of set foreground color 0x${rgbcolor.toRadixString(16).padLeft(6)}');
			});

			// Cancellation code removes colour 
			expectSingleSequenceElement('\u001B[${i};39m', (child) {
				expect(child.classes, isEmpty,  reason:'class found on element after foreground cancellation code.');
				expectInlineColor(child, 'foreground', null, 'Custom color style still found after foreground cancellation code.');
			});
		}

    // foreground BRIGHT color codes
    for (int i = 90; i <= 97; i++) {
      final int rgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(i)!;
 
			// Foreground colour, NO class
			expectSingleSequenceElement('\u001B[${i}m', (child) {
				expect(child.classes, isEmpty, reason:'class found on element after foreground ANSI code #${i}.');
				expectInlineColor(child, 'foreground', rgbcolor, 'ANSI color style $i should of set foreground color 0x${rgbcolor.toRadixString(16).padLeft(6)}');
			});

			// Cancellation code removes colour
			expectSingleSequenceElement('\u001B[${i};39m', (child) {
				expect(child.classes, isEmpty,  reason:'class found on element after foreground cancellation code.');
				expectInlineColor(child, 'foreground', null, 'Custom color style still found after foreground cancellation code.');
			});
		}

    // background color codes
    for (int i = 40; i <= 47; i++) {
      final int rgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(i)!;
     
			// background colour, NO class
			expectSingleSequenceElement('\u001B[${i}m', (child) {
				expect(child.classes, isEmpty, reason:'class found on element after background ANSI code #${i}.');
				expectInlineColor(child, 'background', rgbcolor, 'ANSI color style $i should of set background color 0x${rgbcolor.toRadixString(16).padLeft(6)}');
			});

			// Cancellation code removes colour 
			expectSingleSequenceElement('\u001B[${i};39m', (child) {
				expect(child.classes, isEmpty,  reason:'class found on element after background cancellation code.');
				expectInlineColor(child, 'background', null, 'Custom color style still found after background cancellation code.');
			});
		}
    // background BRIGHT color codes
    for (int i = 100; i <= 107; i++) {
      final int rgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(i)!;
 
  		// background colour, NO class
			expectSingleSequenceElement('\u001B[${i}m', (child) {
				expect(child.classes, isEmpty, reason:'class found on element after foreground ANSI code #${i}.');
				expectInlineColor(child, 'background', rgbcolor, 'ANSI color style $i should of set background color 0x${rgbcolor.toRadixString(16).padLeft(6)}');
			});

			// Cancellation code removes colour
			expectSingleSequenceElement('\u001B[${i};39m', (child) {
				expect(child.classes, isEmpty,  reason:'class found on element after background cancellation code.');
				expectInlineColor(child, 'background', null, 'Custom color style still found after background cancellation code.');
			});
		}

    // check all basic colors for underlines (full range is checked elsewhere, here we check cancelation)
		for (int i = 16; i <= 255; i++) {
      final int rgbcolor = AnsiConsoleHandler.calcAnsi8bitColor(i)!;

			// Underline colour class
			expectSingleSequenceElement('\u001B[58;5;${i}m', (child) {
				expect(child.classes, isEmpty, reason: 'Class found on element after underline color ANSI code 58;5;${i}m.');
				expectInlineColor(child, 'underline', rgbcolor, 'ANSI color style $i should of set underline color 0x${rgbcolor.toRadixString(16).padLeft(6)}');
			});

			// Cancellation underline color code removes colour class
			expectSingleSequenceElement('\u001B[58;5;${i}m\u001B[59m', (child) {
				expect(child.classes, isEmpty,reason: 'Class found after underline color cancellation code 59m.');
				expectInlineColor(child, 'underline', null, 'Custom underline color style still found after underline color cancellation code 59m.');
			});
		}

	// Different codes do not cancel each other
		expectSingleSequenceElement('\u001B[1;3;4;30;41m', (child) {
	    final int fgRgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(30)!;
      final int bgRgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(41)!;
//fuck
double t = 45 / 0;

      expect(child.classes.length, equals(4), reason:'Incorrect number of classes found for different ANSI codes.');
			expect(child.classes, contains('ansi-bold'));
			expect(child.classes, contains('ansi-italic'), reason:'Different ANSI codes should not cancel each other.');
			expect(child.classes, contains('ansi-underline'), reason:'Different ANSI codes should not cancel each other.');
			expectInlineColor(child, 'foreground', fgRgbcolor, 'ANSI color style 30 should of set foreground color 0x${fgRgbcolor.toRadixString(16).padLeft(6)}');
			expectInlineColor(child, 'background', bgRgbcolor, 'ANSI color style 41 should of set background color 0x${bgRgbcolor.toRadixString(16).padLeft(6)}');
		});

		// Different codes do not ACCUMULATE more than one copy of each class
		expectSingleSequenceElement('\u001B[1;1;2;2;3;3;4;4;5;5;6;6;8;8;9;9;21;21;53;53;73;73;74;74m', (child) {
			expect(child.classes, contains('ansi-bold'));
			expect(child.classes, contains('ansi-italic'), reason:'italic missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, isNot(contains('ansi-underline')), reason:'underline PRESENT and double underline should have removed it- Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-dim'), reason:'dim missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-blink'), reason:'blink missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-rapid-blink'), reason:'rapid blink mkssing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-double-underline'), reason:'double underline missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-hidden'), reason:'hidden missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-strike-through'), reason:'strike-through missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-overline'), reason:'overline missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, isNot(contains('ansi-superscript')), reason:'superscript PRESENT and subscript should have removed it- Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes, contains('ansi-subscript'), reason:'subscript missing Doubles of each Different ANSI codes should not cancel each other or accumulate.');
			expect(child.classes.length, equals(10), reason:'Incorrect number of classes found for each style code sent twice ANSI codes.');
		});

		// More Different codes do not cancel each other
		expectSingleSequenceElement('\u001B[1;2;5;6;21;8;9m', (child) {
			expect(child.classes.length, equals(7), reason:'Incorrect number of classes found for different ANSI codes.');
			expect(child.classes, contains('ansi-bold'));
			expect(child.classes, contains('ansi-dim'), reason:'Different ANSI codes should not cancel each other.');
			expect(child.classes, contains('ansi-blink'), reason:'Different ANSI codes should not cancel each other.');
			expect(child.classes, contains('ansi-rapid-blink'), reason:'Different ANSI codes should not cancel each other.');
			expect(child.classes, contains('ansi-double-underline'), reason:'Different ANSI codes should not cancel each other.');
			expect(child.classes, contains('ansi-hidden'), reason:'Different ANSI codes should not cancel each other.');
			expect(child.classes, contains('ansi-strike-through'), reason:'Different ANSI codes should not cancel each other.');
		});

		// New foreground codes don't remove old background codes and vice versa
		expectSingleSequenceElement('\u001B[40;31;42;33m', (child) {
			expect(child.classes.length, equals(0));

	    final int fgRgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(33)!;
      final int bgRgbcolor = ansiConsoleHandler.getColorFromBasicAnsiColorCode(42)!;
		
   		expectInlineColor(child, 'foreground', fgRgbcolor, 'ANSI color style 33 should of set foreground color 0x${fgRgbcolor.toRadixString(16).padLeft(6)}');
			expectInlineColor(child, 'background', bgRgbcolor, 'ANSI color style 42 should of set background color 0x${bgRgbcolor.toRadixString(16).padLeft(6)}');
		});

		// Duplicate codes do not change output
		expectSingleSequenceElement('\u001B[1;1;4;1;4;4;1;4m', (child) {
      expect(child.classes.length, equals(2));
			expect(child.classes, contains('ansi-bold'), reason:'Duplicate formatting codes should have no effect.');
			expect(child.classes, contains('ansi-underline'), reason:'Duplicate formatting codes should have no effect.');
		});

		// Extra terminating semicolon does not change output
		expectSingleSequenceElement('\u001B[1;4;m', (child) {
      expect(child.classes.length, equals(2));
			expect(child.classes, contains('ansi-bold'), reason:'Extra semicolon after ANSI codes should have no effect.');
			expect(child.classes, contains('ansi-underline'), reason:'Extra semicolon after ANSI codes should have no effect.');
		});

		// Cancellation code (0) removes multiple codes
		expectSingleSequenceElement('\u001B[1;4;30;41;32;43;34;45;36;47;0m', (child) {
			expect(child.classes.length, equals(0), reason:'Cancellation ANSI code should clear ALL formatting.');
			expectInlineColor(child, 'background', null, 'Cancellation ANSI code should clear ALL formatting, including background color.');
			expectInlineColor(child, 'foreground', null, 'Cancellation ANSI code should clear ALL formatting, including foreground color.');
		});

  } );


	test('Expected single 8-bit color sequence operation', () {
		// Basic and bright color codes specified with 8-bit color code format
		for (int i = 0; i <= 15; i++) {
      // USE DARK MODE THEME, that is what we instaniated the Class with
      final int rgbcolor = AnsiConsoleHandler.darkModeAnsiColors[i];

			// As these are controlled by theme, difficult to check actual color value
			// Foreground codes should add standard classes
			expectSingleSequenceElement('\u001B[38;5;${i}m', (child) {
  			expectInlineColor(child, 'foreground', rgbcolor, 'Custom color class not found after foreground 8-bit color code 38;5;${i}');
	    });
		
			// Background codes should add standard classes
			expectSingleSequenceElement('\u001B[48;5;${i}m', (child) {
	    	expectInlineColor(child, 'background', rgbcolor, 'Custom color class not found after background 8-bit color code 48;5;${i}');
			});
		}

		// 8-bit advanced colors
		for (int i = 16; i <= 255; i++) {
			// Foreground codes should add custom class and inline style
			expectSingleSequenceElement('\u001B[38;5;${i}m', (child) {
				expect(child.classes, isEmpty, reason:'Class found foreground 8-bit color code 38;5;${i}');
				expectInlineColor(child, 'foreground', AnsiConsoleHandler.calcAnsi8bitColor(i), 'Incorrect or no color styling found after foreground 8-bit color code 38;5;${i}');
			});

			// Background codes should add custom class and inline style
			expectSingleSequenceElement('\u001B[48;5;${i}m', (child) {
				expect(child.classes, isEmpty, reason:'Class found after background 8-bit color code 48;5;${i}');
				expectInlineColor(child, 'background', AnsiConsoleHandler.calcAnsi8bitColor(i), 'Incorrect or no color styling found after background 8-bit color code 48;5;${i}');
			});

			// Color underline codes should add custom class and inline style
			expectSingleSequenceElement('\u001B[58;5;${i}m', (child) {
				expect(child.classes, isEmpty, reason:'Class found after underline 8-bit color code 58;5;${i}');
				expectInlineColor(child, 'underline', AnsiConsoleHandler.calcAnsi8bitColor(i), 'Incorrect or no color styling found after underline 8-bit color code 58;5;${i}');
			});
		}

		// Bad (nonexistent) color should not render
		expectSingleSequenceElement('\u001B[48;5;300m', (child) {
			expect(child.classes.length, equals(0), reason:'Bad ANSI color codes should have no effect.');
		});

		// Should ignore any codes after the ones needed to determine color
		expectSingleSequenceElement('\u001B[48;5;100;42;77;99;4;24m', (child) {
			expect(child.classes, isEmpty);
			expectInlineColor(child, 'background', AnsiConsoleHandler.calcAnsi8bitColor(100),'Should ignore any codes after the ones needed to determine color');
		});
	});





  }); // group


  group('ansi_console_tests', () {
    
    test('get stream changes', () {
        expect('abc',equals('abc'));
      }
    );
    
    test('get property changes', () {
     
      });


  });


/*


group('Debug - ANSI Handling', () {

	test('Expected single sequence operation', () => {

		

		
  });

});
*/

}

/*


		
	




	});

	test('Expected single 24-bit color sequence operation', () => {
		// 24-bit advanced colors
		for (int r = 0; r <= 255; r += 64) {
			for (int g = 0; g <= 255; g += 64) {
				for (int b = 0; b <= 255; b += 64) {
					const color = new RGBA(r, g, b);
					// Foreground codes should add class and inline style
					expectSingleSequenceElement('\u001B[38;2;${r};${g};${b}m', (child) => {
						expect(child.classes.contains('ansi-foreground-colored'), 'DOM should have "ansi-foreground-colored" class for advanced ANSI colors.');
						expectInlineColor(child, 'foreground', color);
					});

					// Background codes should add class and inline style
					expectSingleSequenceElement('\u001B[48;2;${r};${g};${b}m', (child) => {
						expect(child.classes.contains('ansi-background-colored'), 'DOM should have "ansi-foreground-colored" class for advanced ANSI colors.');
						expectInlineColor(child, 'background', color);
					});

					// Underline color codes should add class and inline style
					expectSingleSequenceElement('\u001B[58;2;${r};${g};${b}m', (child) => {
						expect(child.classes.contains('ansi-underline-colored'), 'DOM should have "ansi-underline-colored" class for advanced ANSI colors.');
						expectInlineColor(child, 'underline', color);
					});
				}
			}
		}

		// Invalid color should not render
		expectSingleSequenceElement('\u001B[38;2;4;4m', (child) => {
			expect.strictEqual(0, child.classes.length, 'Invalid color code "38;2;4;4" should not add a class (classes found: ${child.classes}).');
			expect(!child.style.color, 'Invalid color code "38;2;4;4" should not add a custom color CSS (found color: ${child.style.color}).');
		});

		// Bad (nonexistent) color should not render
		expectSingleSequenceElement('\u001B[48;2;150;300;5m', (child) => {
			expect.strictEqual(0, child.classes.length, 'Nonexistent color code "48;2;150;300;5" should not add a class (classes found: ${child.classes}).');
		});

		// Should ignore any codes after the ones needed to determine color
		expectSingleSequenceElement('\u001B[48;2;100;42;77;99;200;75m', (child) => {
			expect(child.classes.contains('ansi-background-colored'), 'Color code with extra (valid) items "48;2;100;42;77;99;200;75" should still treat initial part as valid code and add class "ansi-background-custom".');
			expect.strictEqual(1, child.classes.length, 'Color code with extra items "48;2;100;42;77;99;200;75" should add one and only one class. (classes found: ${child.classes}).');
			expectInlineColor(child, 'background', new RGBA(100, 42, 77), 'Color code "48;2;100;42;77;99;200;75" should  style background-color as rgb(100,42,77).');
		});
	});


	/// 
	/// expect that a given ANSI sequence produces the expected number of {@link HTMLSpanElement} children. For
	/// each child, run the provided expectation.
	/// 
	/// @param sequence The ANSI sequence to verify.
	/// @param expectations A set of expectations to run on the resulting children.
	/// 
	function expectMultipleSequenceElements(sequence: string, expectations: Array<(child: HTMLSpanElement) => void>, elementsExpected?: number): void {
		if (elementsExpected == null) {
			elementsExpected = expectations.length;
		}
		const root: HTMLSpanElement = handleANSIOutput(sequence, linkDetector, themeService, session.root);
		expect.strictEqual(elementsExpected, root.children.length);
		for (int i = 0; i < elementsExpected; i++) {
			const child: Node = root.children[i];
			if (child instanceof HTMLSpanElement) {
				expectations[i](child);
			} else {
				expect.fail('Unexpected expectation error');
			}
		}
	}

	test('Expected multiple sequence operation', () => {

		// Multiple codes affect the same text
		expectSingleSequenceElement('\u001B[1m\u001B[3m\u001B[4m\u001B[32m', (child) => {
			expect(child.classes.contains('ansi-bold'), 'Bold class not found after multiple different ANSI codes.');
			expect(child.classes.contains('ansi-italic'), 'Italic class not found after multiple different ANSI codes.');
			expect(child.classes.contains('ansi-underline'), 'Underline class not found after multiple different ANSI codes.');
			expect(child.classes.contains('ansi-foreground-colored'), 'Foreground color class not found after multiple different ANSI codes.');
		});

		// Consecutive codes do not affect previous ones
		expectMultipleSequenceElements('\u001B[1mbold\u001B[32mgreen\u001B[4munderline\u001B[3mitalic\u001B[0mnothing', [
			(bold) => {
				expect.strictEqual(1, bold.classes.length);
				expect(bold.classes.contains('ansi-bold'), 'Bold class not found after bold ANSI code.');
			},
			(green) => {
				expect.strictEqual(2, green.classes.length);
				expect(green.classes.contains('ansi-bold'), 'Bold class not found after both bold and color ANSI codes.');
				expect(green.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(underline) => {
				expect.strictEqual(3, underline.classes.length);
				expect(underline.classes.contains('ansi-bold'), 'Bold class not found after bold, color, and underline ANSI codes.');
				expect(underline.classes.contains('ansi-foreground-colored'), 'Color class not found after color and underline ANSI codes.');
				expect(underline.classes.contains('ansi-underline'), 'Underline class not found after underline ANSI code.');
			},
			(italic) => {
				expect.strictEqual(4, italic.classes.length);
				expect(italic.classes.contains('ansi-bold'), 'Bold class not found after bold, color, underline, and italic ANSI codes.');
				expect(italic.classes.contains('ansi-foreground-colored'), 'Color class not found after color, underline, and italic ANSI codes.');
				expect(italic.classes.contains('ansi-underline'), 'Underline class not found after underline and italic ANSI codes.');
				expect(italic.classes.contains('ansi-italic'), 'Italic class not found after italic ANSI code.');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after reset ANSI code.');
			},
		], 5);

		// Consecutive codes with ENDING/OFF codes do not LEAVE affect previous ones
		expectMultipleSequenceElements('\u001B[1mbold\u001B[22m\u001B[32mgreen\u001B[4munderline\u001B[24m\u001B[3mitalic\u001B[23mjustgreen\u001B[0mnothing', [
			(bold) => {
				expect.strictEqual(1, bold.classes.length);
				expect(bold.classes.contains('ansi-bold'), 'Bold class not found after bold ANSI code.');
			},
			(green) => {
				expect.strictEqual(1, green.classes.length);
				expect(green.classes.contains('ansi-bold') == false, 'Bold class found after both bold WAS TURNED OFF with 22m');
				expect(green.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(underline) => {
				expect.strictEqual(2, underline.classes.length);
				expect(underline.classes.contains('ansi-foreground-colored'), 'Color class not found after color and underline ANSI codes.');
				expect(underline.classes.contains('ansi-underline'), 'Underline class not found after underline ANSI code.');
			},
			(italic) => {
				expect.strictEqual(2, italic.classes.length);
				expect(italic.classes.contains('ansi-foreground-colored'), 'Color class not found after color, underline, and italic ANSI codes.');
				expect(italic.classes.contains('ansi-underline') == false, 'Underline class found after underline WAS TURNED OFF with 24m');
				expect(italic.classes.contains('ansi-italic'), 'Italic class not found after italic ANSI code.');
			},
			(justgreen) => {
				expect.strictEqual(1, justgreen.classes.length);
				expect(justgreen.classes.contains('ansi-italic') == false, 'Italic class found after italic WAS TURNED OFF with 23m');
				expect(justgreen.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after reset ANSI code.');
			},
		], 6);

		// more Consecutive codes with ENDING/OFF codes do not LEAVE affect previous ones
		expectMultipleSequenceElements('\u001B[2mdim\u001B[22m\u001B[32mgreen\u001B[5mslowblink\u001B[25m\u001B[6mrapidblink\u001B[25mjustgreen\u001B[0mnothing', [
			(dim) => {
				expect.strictEqual(1, dim.classes.length);
				expect(dim.classes.contains('ansi-dim'), 'Dim class not found after dim ANSI code 2m.');
			},
			(green) => {
				expect.strictEqual(1, green.classes.length);
				expect(green.classes.contains('ansi-dim') == false, 'Dim class found after dim WAS TURNED OFF with 22m');
				expect(green.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(slowblink) => {
				expect.strictEqual(2, slowblink.classes.length);
				expect(slowblink.classes.contains('ansi-foreground-colored'), 'Color class not found after color and blink ANSI codes.');
				expect(slowblink.classes.contains('ansi-blink'), 'Blink class not found after underline ANSI code 5m.');
			},
			(rapidblink) => {
				expect.strictEqual(2, rapidblink.classes.length);
				expect(rapidblink.classes.contains('ansi-foreground-colored'), 'Color class not found after color, blink, and rapid blink ANSI codes.');
				expect(rapidblink.classes.contains('ansi-blink') == false, 'blink class found after underline WAS TURNED OFF with 25m');
				expect(rapidblink.classes.contains('ansi-rapid-blink'), 'Rapid blink class not found after rapid blink ANSI code 6m.');
			},
			(justgreen) => {
				expect.strictEqual(1, justgreen.classes.length);
				expect(justgreen.classes.contains('ansi-rapid-blink') == false, 'Rapid blink class found after rapid blink WAS TURNED OFF with 25m');
				expect(justgreen.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after reset ANSI code.');
			},
		], 6);

		// more Consecutive codes with ENDING/OFF codes do not LEAVE affect previous ones
		expectMultipleSequenceElements('\u001B[8mhidden\u001B[28m\u001B[32mgreen\u001B[9mcrossedout\u001B[29m\u001B[21mdoubleunderline\u001B[24mjustgreen\u001B[0mnothing', [
			(hidden) => {
				expect.strictEqual(1, hidden.classes.length);
				expect(hidden.classes.contains('ansi-hidden'), 'Hidden class not found after dim ANSI code 8m.');
			},
			(green) => {
				expect.strictEqual(1, green.classes.length);
				expect(green.classes.contains('ansi-hidden') == false, 'Hidden class found after Hidden WAS TURNED OFF with 28m');
				expect(green.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(crossedout) => {
				expect.strictEqual(2, crossedout.classes.length);
				expect(crossedout.classes.contains('ansi-foreground-colored'), 'Color class not found after color and hidden ANSI codes.');
				expect(crossedout.classes.contains('ansi-strike-through'), 'strike-through class not found after crossout/strikethrough ANSI code 9m.');
			},
			(doubleunderline) => {
				expect.strictEqual(2, doubleunderline.classes.length);
				expect(doubleunderline.classes.contains('ansi-foreground-colored'), 'Color class not found after color, hidden, and crossedout ANSI codes.');
				expect(doubleunderline.classes.contains('ansi-strike-through') == false, 'strike-through class found after strike-through WAS TURNED OFF with 29m');
				expect(doubleunderline.classes.contains('ansi-double-underline'), 'Double underline class not found after double underline ANSI code 21m.');
			},
			(justgreen) => {
				expect.strictEqual(1, justgreen.classes.length);
				expect(justgreen.classes.contains('ansi-double-underline') == false, 'Double underline class found after double underline WAS TURNED OFF with 24m');
				expect(justgreen.classes.contains('ansi-foreground-colored'), 'Color class not found after color ANSI code.');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after reset ANSI code.');
			},
		], 6);

		// underline, double underline are mutually exclusive, test underline->double underline->off and double underline->underline->off
		expectMultipleSequenceElements('\u001B[4munderline\u001B[21mdouble underline\u001B[24munderlineOff\u001B[21mdouble underline\u001B[4munderline\u001B[24munderlineOff', [
			(underline) => {
				expect.strictEqual(1, underline.classes.length);
				expect(underline.classes.contains('ansi-underline'), 'Underline class not found after underline ANSI code 4m.');
			},
			(doubleunderline) => {
				expect(doubleunderline.classes.contains('ansi-underline') == false, 'Underline class found after double underline code 21m');
				expect(doubleunderline.classes.contains('ansi-double-underline'), 'Double underline class not found after double underline code 21m');
				expect.strictEqual(1, doubleunderline.classes.length, 'should have found only double underline');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after underline off code 4m.');
			},
			(doubleunderline) => {
				expect(doubleunderline.classes.contains('ansi-double-underline'), 'Double underline class not found after double underline code 21m');
				expect.strictEqual(1, doubleunderline.classes.length, 'should have found only double underline');
			},
			(underline) => {
				expect(underline.classes.contains('ansi-double-underline') == false, 'Double underline class found after underline code 4m');
				expect(underline.classes.contains('ansi-underline'), 'Underline class not found after underline ANSI code 4m.');
				expect.strictEqual(1, underline.classes.length, 'should have found only underline');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after underline off code 4m.');
			},
		], 6);

		// underline and strike-through and overline can exist at the same time and
		// in any combination
		expectMultipleSequenceElements('\u001B[4munderline\u001B[9mand strikethough\u001B[53mand overline\u001B[24munderlineOff\u001B[55moverlineOff\u001B[29mstriklethoughOff', [
			(underline) => {
				expect.strictEqual(1, underline.classes.length, 'should have found only underline');
				expect(underline.classes.contains('ansi-underline'), 'Underline class not found after underline ANSI code 4m.');
			},
			(strikethrough) => {
				expect(strikethrough.classes.contains('ansi-underline'), 'Underline class NOT found after strikethrough code 9m');
				expect(strikethrough.classes.contains('ansi-strike-through'), 'Strike through class not found after strikethrough code 9m');
				expect.strictEqual(2, strikethrough.classes.length, 'should have found underline and strikethrough');
			},
			(overline) => {
				expect(overline.classes.contains('ansi-underline'), 'Underline class NOT found after overline code 53m');
				expect(overline.classes.contains('ansi-strike-through'), 'Strike through class not found after overline code 53m');
				expect(overline.classes.contains('ansi-overline'), 'Overline class not found after overline code 53m');
				expect.strictEqual(3, overline.classes.length, 'should have found underline,strikethrough and overline');
			},
			(underlineoff) => {
				expect(underlineoff.classes.contains('ansi-underline') == false, 'Underline class found after underline off code 24m');
				expect(underlineoff.classes.contains('ansi-strike-through'), 'Strike through class not found after underline off code 24m');
				expect(underlineoff.classes.contains('ansi-overline'), 'Overline class not found after underline off code 24m');
				expect.strictEqual(2, underlineoff.classes.length, 'should have found strikethrough and overline');
			},
			(overlineoff) => {
				expect(overlineoff.classes.contains('ansi-underline') == false, 'Underline class found after overline off code 55m');
				expect(overlineoff.classes.contains('ansi-overline') == false, 'Overline class found after overline off code 55m');
				expect(overlineoff.classes.contains('ansi-strike-through'), 'Strike through class not found after overline off code 55m');
				expect.strictEqual(1, overlineoff.classes.length, 'should have found only strikethrough');
			},
			(nothing) => {
				expect(nothing.classes.contains('ansi-strike-through') == false, 'Strike through class found after strikethrough off code 29m');
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after strikethough OFF code 29m');
			},
		], 6);

		// double underline and strike-through and overline can exist at the same time and
		// in any combination
		expectMultipleSequenceElements('\u001B[21mdoubleunderline\u001B[9mand strikethough\u001B[53mand overline\u001B[29mstriklethoughOff\u001B[55moverlineOff\u001B[24munderlineOff', [
			(doubleunderline) => {
				expect.strictEqual(1, doubleunderline.classes.length, 'should have found only doubleunderline');
				expect(doubleunderline.classes.contains('ansi-double-underline'), 'Double underline class not found after double underline ANSI code 21m.');
			},
			(strikethrough) => {
				expect(strikethrough.classes.contains('ansi-double-underline'), 'Double nderline class NOT found after strikethrough code 9m');
				expect(strikethrough.classes.contains('ansi-strike-through'), 'Strike through class not found after strikethrough code 9m');
				expect.strictEqual(2, strikethrough.classes.length, 'should have found doubleunderline and strikethrough');
			},
			(overline) => {
				expect(overline.classes.contains('ansi-double-underline'), 'Double underline class NOT found after overline code 53m');
				expect(overline.classes.contains('ansi-strike-through'), 'Strike through class not found after overline code 53m');
				expect(overline.classes.contains('ansi-overline'), 'Overline class not found after overline code 53m');
				expect.strictEqual(3, overline.classes.length, 'should have found doubleunderline,overline and strikethrough');
			},
			(strikethrougheoff) => {
				expect(strikethrougheoff.classes.contains('ansi-double-underline'), 'Double underline class NOT found after strikethrough off code 29m');
				expect(strikethrougheoff.classes.contains('ansi-overline'), 'Overline class NOT found after strikethrough off code 29m');
				expect(strikethrougheoff.classes.contains('ansi-strike-through') == false, 'Strike through class found after strikethrough off code 29m');
				expect.strictEqual(2, strikethrougheoff.classes.length, 'should have found doubleunderline and overline');
			},
			(overlineoff) => {
				expect(overlineoff.classes.contains('ansi-double-underline'), 'Double underline class NOT found after overline off code 55m');
				expect(overlineoff.classes.contains('ansi-strike-through') == false, 'Strike through class found after overline off code 55m');
				expect(overlineoff.classes.contains('ansi-overline') == false, 'Overline class found after overline off code 55m');
				expect.strictEqual(1, overlineoff.classes.length, 'Should have found only double underline');
			},
			(nothing) => {
				expect(nothing.classes.contains('ansi-double-underline') == false, 'Double underline class found after underline off code 24m');
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after underline OFF code 24m');
			},
		], 6);

		// superscript and subscript are mutually exclusive, test superscript->subscript->off and subscript->superscript->off
		expectMultipleSequenceElements('\u001B[73msuperscript\u001B[74msubscript\u001B[75mneither\u001B[74msubscript\u001B[73msuperscript\u001B[75mneither', [
			(superscript) => {
				expect.strictEqual(1, superscript.classes.length, 'should only be superscript class');
				expect(superscript.classes.contains('ansi-superscript'), 'Superscript class not found after superscript ANSI code 73m.');
			},
			(subscript) => {
				expect(subscript.classes.contains('ansi-superscript') == false, 'Superscript class found after subscript code 74m');
				expect(subscript.classes.contains('ansi-subscript'), 'Subscript class not found after subscript code 74m');
				expect.strictEqual(1, subscript.classes.length, 'should have found only subscript class');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after superscript/subscript off code 75m.');
			},
			(subscript) => {
				expect(subscript.classes.contains('ansi-subscript'), 'Subscript class not found after subscript code 74m');
				expect.strictEqual(1, subscript.classes.length, 'should have found only subscript class');
			},
			(superscript) => {
				expect(superscript.classes.contains('ansi-subscript') == false, 'Subscript class found after superscript code 73m');
				expect(superscript.classes.contains('ansi-superscript'), 'Superscript class not found after superscript ANSI code 73m.');
				expect.strictEqual(1, superscript.classes.length, 'should have found only superscript class');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more style classes still found after superscipt/subscript off code 75m.');
			},
		], 6);

		// Consecutive font codes switch to new font class and remove previous and then final switch to default font removes class
		expectMultipleSequenceElements('\u001B[11mFont1\u001B[12mFont2\u001B[13mFont3\u001B[14mFont4\u001B[15mFont5\u001B[10mdefaultFont', [
			(font1) => {
				expect.strictEqual(1, font1.classes.length);
				expect(font1.classes.contains('ansi-font-1'), 'font 1 class NOT found after switch to font 1 with ANSI code 11m');
			},
			(font2) => {
				expect.strictEqual(1, font2.classes.length);
				expect(font2.classes.contains('ansi-font-1') == false, 'font 1 class found after switch to font 2 with ANSI code 12m');
				expect(font2.classes.contains('ansi-font-2'), 'font 2 class NOT found after switch to font 2 with ANSI code 12m');
			},
			(font3) => {
				expect.strictEqual(1, font3.classes.length);
				expect(font3.classes.contains('ansi-font-2') == false, 'font 2 class found after switch to font 3 with ANSI code 13m');
				expect(font3.classes.contains('ansi-font-3'), 'font 3 class NOT found after switch to font 3 with ANSI code 13m');
			},
			(font4) => {
				expect.strictEqual(1, font4.classes.length);
				expect(font4.classes.contains('ansi-font-3') == false, 'font 3 class found after switch to font 4 with ANSI code 14m');
				expect(font4.classes.contains('ansi-font-4'), 'font 4 class NOT found after switch to font 4 with ANSI code 14m');
			},
			(font5) => {
				expect.strictEqual(1, font5.classes.length);
				expect(font5.classes.contains('ansi-font-4') == false, 'font 4 class found after switch to font 5 with ANSI code 15m');
				expect(font5.classes.contains('ansi-font-5'), 'font 5 class NOT found after switch to font 5 with ANSI code 15m');
			},
			(defaultfont) => {
				expect.strictEqual(0, defaultfont.classes.length, 'One or more font style classes still found after reset to default font with ANSI code 10m.');
			},
		], 6);

		// More Consecutive font codes switch to new font class and remove previous and then final switch to default font removes class
		expectMultipleSequenceElements('\u001B[16mFont6\u001B[17mFont7\u001B[18mFont8\u001B[19mFont9\u001B[20mFont10\u001B[10mdefaultFont', [
			(font6) => {
				expect.strictEqual(1, font6.classes.length);
				expect(font6.classes.contains('ansi-font-6'), 'font 6 class NOT found after switch to font 6 with ANSI code 16m');
			},
			(font7) => {
				expect.strictEqual(1, font7.classes.length);
				expect(font7.classes.contains('ansi-font-6') == false, 'font 6 class found after switch to font 7 with ANSI code 17m');
				expect(font7.classes.contains('ansi-font-7'), 'font 7 class NOT found after switch to font 7 with ANSI code 17m');
			},
			(font8) => {
				expect.strictEqual(1, font8.classes.length);
				expect(font8.classes.contains('ansi-font-7') == false, 'font 7 class found after switch to font 8 with ANSI code 18m');
				expect(font8.classes.contains('ansi-font-8'), 'font 8 class NOT found after switch to font 8 with ANSI code 18m');
			},
			(font9) => {
				expect.strictEqual(1, font9.classes.length);
				expect(font9.classes.contains('ansi-font-8') == false, 'font 8 class found after switch to font 9 with ANSI code 19m');
				expect(font9.classes.contains('ansi-font-9'), 'font 9 class NOT found after switch to font 9 with ANSI code 19m');
			},
			(font10) => {
				expect.strictEqual(1, font10.classes.length);
				expect(font10.classes.contains('ansi-font-9') == false, 'font 9 class found after switch to font 10 with ANSI code 20m');
				expect(font10.classes.contains('ansi-font-10'), 'font 10 class NOT found after switch to font 10 with ANSI code 20m (${font10.classes})');
			},
			(defaultfont) => {
				expect.strictEqual(0, defaultfont.classes.length, 'One or more font style classes (2nd series) still found after reset to default font with ANSI code 10m.');
			},
		], 6);

		// Blackletter font codes can be turned off with other font codes or 23m
		expectMultipleSequenceElements('\u001B[3mitalic\u001B[20mfont10blacklatter\u001B[23mitalicAndBlackletterOff\u001B[20mFont10Again\u001B[11mFont1\u001B[10mdefaultFont', [
			(italic) => {
				expect.strictEqual(1, italic.classes.length);
				expect(italic.classes.contains('ansi-italic'), 'italic class NOT found after italic code ANSI code 3m');
			},
			(font10) => {
				expect.strictEqual(2, font10.classes.length);
				expect(font10.classes.contains('ansi-italic'), 'no itatic class found after switch to font 10 (blackletter) with ANSI code 20m');
				expect(font10.classes.contains('ansi-font-10'), 'font 10 class NOT found after switch to font 10 with ANSI code 20m');
			},
			(italicAndBlackletterOff) => {
				expect.strictEqual(0, italicAndBlackletterOff.classes.length, 'italic or blackletter (font10) class found after both switched off with ANSI code 23m');
			},
			(font10) => {
				expect.strictEqual(1, font10.classes.length);
				expect(font10.classes.contains('ansi-font-10'), 'font 10 class NOT found after switch to font 10 with ANSI code 20m');
			},
			(font1) => {
				expect.strictEqual(1, font1.classes.length);
				expect(font1.classes.contains('ansi-font-10') == false, 'font 10 class found after switch to font 1 with ANSI code 11m');
				expect(font1.classes.contains('ansi-font-1'), 'font 1 class NOT found after switch to font 1 with ANSI code 11m');
			},
			(defaultfont) => {
				expect.strictEqual(0, defaultfont.classes.length, 'One or more font style classes (2nd series) still found after reset to default font with ANSI code 10m.');
			},
		], 6);

		// italic can be turned on/off with affecting font codes 1-9  (italic off will clear 'blackletter'(font 23) as per spec)
		expectMultipleSequenceElements('\u001B[3mitalic\u001B[12mfont2\u001B[23mitalicOff\u001B[3mitalicFont2\u001B[10mjustitalic\u001B[23mnothing', [
			(italic) => {
				expect.strictEqual(1, italic.classes.length);
				expect(italic.classes.contains('ansi-italic'), 'italic class NOT found after italic code ANSI code 3m');
			},
			(font10) => {
				expect.strictEqual(2, font10.classes.length);
				expect(font10.classes.contains('ansi-italic'), 'no itatic class found after switch to font 2 with ANSI code 12m');
				expect(font10.classes.contains('ansi-font-2'), 'font 2 class NOT found after switch to font 2 with ANSI code 12m');
			},
			(italicOff) => {
				expect.strictEqual(1, italicOff.classes.length, 'italic class found after both switched off with ANSI code 23m');
				expect(italicOff.classes.contains('ansi-italic') == false, 'itatic class found after switching it OFF with ANSI code 23m');
				expect(italicOff.classes.contains('ansi-font-2'), 'font 2 class NOT found after switching italic off with ANSI code 23m');
			},
			(italicFont2) => {
				expect.strictEqual(2, italicFont2.classes.length);
				expect(italicFont2.classes.contains('ansi-italic'), 'no itatic class found after italic ANSI code 3m');
				expect(italicFont2.classes.contains('ansi-font-2'), 'font 2 class NOT found after italic ANSI code 3m');
			},
			(justitalic) => {
				expect.strictEqual(1, justitalic.classes.length);
				expect(justitalic.classes.contains('ansi-font-2') == false, 'font 2 class found after switch to default font with ANSI code 10m');
				expect(justitalic.classes.contains('ansi-italic'), 'italic class NOT found after switch to default font with ANSI code 10m');
			},
			(nothing) => {
				expect.strictEqual(0, nothing.classes.length, 'One or more classes still found after final italic removal with ANSI code 23m.');
			},
		], 6);

		// Reverse video reverses Foreground/Background colors WITH both SET and can called in sequence
		expectMultipleSequenceElements('\u001B[38;2;10;20;30mfg10,20,30\u001B[48;2;167;168;169mbg167,168,169\u001B[7m8ReverseVideo\u001B[7mDuplicateReverseVideo\u001B[27mReverseOff\u001B[27mDupReverseOff', [
			(fg10_20_30) => {
				expect.strictEqual(1, fg10_20_30.classes.length, 'Foreground ANSI color code should add one class.');
				expect(fg10_20_30.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(fg10_20_30, 'foreground', new RGBA(10, 20, 30), '24-bit RGBA ANSI color code (10,20,30) should add matching color inline style.');
			},
			(bg167_168_169) => {
				expect.strictEqual(2, bg167_168_169.classes.length, 'background ANSI color codes should only add a single class.');
				expect(bg167_168_169.classes.contains('ansi-background-colored'), 'Background ANSI color codes should add custom background color class.');
				expectInlineColor(bg167_168_169, 'background', new RGBA(167, 168, 169), '24-bit RGBA ANSI background color code (167,168,169) should add matching color inline style.');
				expect(bg167_168_169.classes.contains('ansi-foreground-colored'), 'Still Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(bg167_168_169, 'foreground', new RGBA(10, 20, 30), 'Still 24-bit RGBA ANSI color code (10,20,30) should add matching color inline style.');
			},
			(reverseVideo) => {
				expect.strictEqual(2, reverseVideo.classes.length, 'background ANSI color codes should only add a single class.');
				expect(reverseVideo.classes.contains('ansi-background-colored'), 'Background ANSI color codes should add custom background color class.');
				expectInlineColor(reverseVideo, 'foreground', new RGBA(167, 168, 169), 'Reversed 24-bit RGBA ANSI foreground color code (167,168,169) should add matching former background color inline style.');
				expect(reverseVideo.classes.contains('ansi-foreground-colored'), 'Still Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(reverseVideo, 'background', new RGBA(10, 20, 30), 'Reversed 24-bit RGBA ANSI background color code (10,20,30) should add matching former foreground color inline style.');
			},
			(dupReverseVideo) => {
				expect.strictEqual(2, dupReverseVideo.classes.length, 'After second Reverse Video - background ANSI color codes should only add a single class.');
				expect(dupReverseVideo.classes.contains('ansi-background-colored'), 'After second Reverse Video - Background ANSI color codes should add custom background color class.');
				expectInlineColor(dupReverseVideo, 'foreground', new RGBA(167, 168, 169), 'After second Reverse Video - Reversed 24-bit RGBA ANSI foreground color code (167,168,169) should add matching former background color inline style.');
				expect(dupReverseVideo.classes.contains('ansi-foreground-colored'), 'After second Reverse Video - Still Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(dupReverseVideo, 'background', new RGBA(10, 20, 30), 'After second Reverse Video - Reversed 24-bit RGBA ANSI background color code (10,20,30) should add matching former foreground color inline style.');
			},
			(reversedBack) => {
				expect.strictEqual(2, reversedBack.classes.length, 'Reversed Back - background ANSI color codes should only add a single class.');
				expect(reversedBack.classes.contains('ansi-background-colored'), 'Reversed Back - Background ANSI color codes should add custom background color class.');
				expectInlineColor(reversedBack, 'background', new RGBA(167, 168, 169), 'Reversed Back - 24-bit RGBA ANSI background color code (167,168,169) should add matching color inline style.');
				expect(reversedBack.classes.contains('ansi-foreground-colored'), 'Reversed Back -  Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(reversedBack, 'foreground', new RGBA(10, 20, 30), 'Reversed Back -  24-bit RGBA ANSI color code (10,20,30) should add matching color inline style.');
			},
			(dupReversedBack) => {
				expect.strictEqual(2, dupReversedBack.classes.length, '2nd Reversed Back - background ANSI color codes should only add a single class.');
				expect(dupReversedBack.classes.contains('ansi-background-colored'), '2nd Reversed Back - Background ANSI color codes should add custom background color class.');
				expectInlineColor(dupReversedBack, 'background', new RGBA(167, 168, 169), '2nd Reversed Back - 24-bit RGBA ANSI background color code (167,168,169) should add matching color inline style.');
				expect(dupReversedBack.classes.contains('ansi-foreground-colored'), '2nd Reversed Back -  Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(dupReversedBack, 'foreground', new RGBA(10, 20, 30), '2nd Reversed Back -  24-bit RGBA ANSI color code (10,20,30) should add matching color inline style.');
			},
		], 6);

		// Reverse video reverses Foreground/Background colors WITH ONLY foreground color SET
		expectMultipleSequenceElements('\u001B[38;2;10;20;30mfg10,20,30\u001B[7m8ReverseVideo\u001B[27mReverseOff', [
			(fg10_20_30) => {
				expect.strictEqual(1, fg10_20_30.classes.length, 'Foreground ANSI color code should add one class.');
				expect(fg10_20_30.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(fg10_20_30, 'foreground', new RGBA(10, 20, 30), '24-bit RGBA ANSI color code (10,20,30) should add matching color inline style.');
			},
			(reverseVideo) => {
				expect.strictEqual(1, reverseVideo.classes.length, 'Background ANSI color codes should only add a single class.');
				expect(reverseVideo.classes.contains('ansi-background-colored'), 'Background ANSI color codes should add custom background color class.');
				expect(reverseVideo.classes.contains('ansi-foreground-colored') == false, 'After Reverse with NO background the Foreground ANSI color codes should NOT BE SET.');
				expectInlineColor(reverseVideo, 'background', new RGBA(10, 20, 30), 'Reversed 24-bit RGBA ANSI background color code (10,20,30) should add matching former foreground color inline style.');
			},
			(reversedBack) => {
				expect.strictEqual(1, reversedBack.classes.length, 'Reversed Back - background ANSI color codes should only add a single class.');
				expect(reversedBack.classes.contains('ansi-background-colored') == false, 'AFTER Reversed Back - Background ANSI color should NOT BE SET.');
				expect(reversedBack.classes.contains('ansi-foreground-colored'), 'Reversed Back -  Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(reversedBack, 'foreground', new RGBA(10, 20, 30), 'Reversed Back -  24-bit RGBA ANSI color code (10,20,30) should add matching color inline style.');
			},
		], 3);

		// Reverse video reverses Foreground/Background colors WITH ONLY background color SET
		expectMultipleSequenceElements('\u001B[48;2;167;168;169mbg167,168,169\u001B[7m8ReverseVideo\u001B[27mReverseOff', [
			(bg167_168_169) => {
				expect.strictEqual(1, bg167_168_169.classes.length, 'Background ANSI color code should add one class.');
				expect(bg167_168_169.classes.contains('ansi-background-colored'), 'Background ANSI color codes should add custom foreground color class.');
				expectInlineColor(bg167_168_169, 'background', new RGBA(167, 168, 169), '24-bit RGBA ANSI color code (167, 168, 169) should add matching background color inline style.');
			},
			(reverseVideo) => {
				expect.strictEqual(1, reverseVideo.classes.length, 'After ReverseVideo Foreground ANSI color codes should only add a single class.');
				expect(reverseVideo.classes.contains('ansi-foreground-colored'), 'After ReverseVideo Foreground ANSI color codes should add custom background color class.');
				expect(reverseVideo.classes.contains('ansi-background-colored') == false, 'After Reverse with NO foreground color the background ANSI color codes should BE SET.');
				expectInlineColor(reverseVideo, 'foreground', new RGBA(167, 168, 169), 'Reversed 24-bit RGBA ANSI background color code (10,20,30) should add matching former background color inline style.');
			},
			(reversedBack) => {
				expect.strictEqual(1, reversedBack.classes.length, 'Reversed Back - background ANSI color codes should only add a single class.');
				expect(reversedBack.classes.contains('ansi-foreground-colored') == false, 'AFTER Reversed Back - Foreground ANSI color should NOT BE SET.');
				expect(reversedBack.classes.contains('ansi-background-colored'), 'Reversed Back -  Background ANSI color codes should add custom background color class.');
				expectInlineColor(reversedBack, 'background', new RGBA(167, 168, 169), 'Reversed Back -  24-bit RGBA ANSI color code (10,20,30) should add matching background color inline style.');
			},
		], 3);

		// Underline color Different types of color codes still cancel each other
		expectMultipleSequenceElements('\u001B[58;2;101;102;103m24bitUnderline101,102,103\u001B[58;5;3m8bitsimpleUnderline\u001B[58;2;104;105;106m24bitUnderline104,105,106\u001B[58;5;101m8bitadvanced\u001B[58;2;200;200;200munderline200,200,200\u001B[59mUnderlineColorResetToDefault', [
			(adv24Bit) => {
				expect.strictEqual(1, adv24Bit.classes.length, 'Underline ANSI color codes should only add a single class (1).');
				expect(adv24Bit.classes.contains('ansi-underline-colored'), 'Underline ANSI color codes should add custom underline color class.');
				expectInlineColor(adv24Bit, 'underline', new RGBA(101, 102, 103), '24-bit RGBA ANSI color code (101,102,103) should add matching color inline style.');
			},
			(adv8BitSimple) => {
				expect.strictEqual(1, adv8BitSimple.classes.length, 'Multiple underline ANSI color codes should only add a single class (2).');
				expect(adv8BitSimple.classes.contains('ansi-underline-colored'), 'Underline ANSI color codes should add custom underline color class.');
				// changed to simple theme color, don't know exactly what it should be, but it should NO LONGER BE 101,102,103
				expectInlineColor(adv8BitSimple, 'underline', new RGBA(101, 102, 103), 'Change to theme color SHOULD NOT STILL BE 24-bit RGBA ANSI color code (101,102,103) should add matching color inline style.', false);
			},
			(adv24BitAgain) => {
				expect.strictEqual(1, adv24BitAgain.classes.length, 'Multiple underline ANSI color codes should only add a single class (3).');
				expect(adv24BitAgain.classes.contains('ansi-underline-colored'), 'Underline ANSI color codes should add custom underline color class.');
				expectInlineColor(adv24BitAgain, 'underline', new RGBA(104, 105, 106), '24-bit RGBA ANSI color code (100,100,100) should add matching color inline style.');
			},
			(adv8BitAdvanced) => {
				expect.strictEqual(1, adv8BitAdvanced.classes.length, 'Multiple underline ANSI color codes should only add a single class (4).');
				expect(adv8BitAdvanced.classes.contains('ansi-underline-colored'), 'Underline ANSI color codes should add custom underline color class.');
				// changed to 8bit advanced color, don't know exactly what it should be, but it should NO LONGER BE 104,105,106
				expectInlineColor(adv8BitAdvanced, 'underline', new RGBA(104, 105, 106), 'Change to theme color SHOULD NOT BE 24-bit RGBA ANSI color code (104,105,106) should add matching color inline style.', false);
			},
			(adv24BitUnderlin200) => {
				expect.strictEqual(1, adv24BitUnderlin200.classes.length, 'Multiple underline ANSI color codes should only add a single class 4.');
				expect(adv24BitUnderlin200.classes.contains('ansi-underline-colored'), 'Underline ANSI color codes should add custom underline color class.');
				expectInlineColor(adv24BitUnderlin200, 'underline', new RGBA(200, 200, 200), 'after change underline color SHOULD BE 24-bit RGBA ANSI color code (200,200,200) should add matching color inline style.');
			},
			(underlineColorResetToDefault) => {
				expect.strictEqual(0, underlineColorResetToDefault.classes.length, 'After Underline Color reset to default NO underline color class should be set.');
				expectInlineColor(underlineColorResetToDefault, 'underline', null, 'after RESET TO DEFAULT underline color SHOULD NOT BE SET (no color inline style.)');
			},
		], 6);

		// Different types of color codes still cancel each other
		expectMultipleSequenceElements('\u001B[34msimple\u001B[38;2;101;102;103m24bit\u001B[38;5;3m8bitsimple\u001B[38;2;104;105;106m24bitAgain\u001B[38;5;101m8bitadvanced', [
			(simple) => {
				expect.strictEqual(1, simple.classes.length, 'Foreground ANSI color code should add one class.');
				expect(simple.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
			},
			(adv24Bit) => {
				expect.strictEqual(1, adv24Bit.classes.length, 'Multiple foreground ANSI color codes should only add a single class.');
				expect(adv24Bit.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(adv24Bit, 'foreground', new RGBA(101, 102, 103), '24-bit RGBA ANSI color code (101,102,103) should add matching color inline style.');
			},
			(adv8BitSimple) => {
				expect.strictEqual(1, adv8BitSimple.classes.length, 'Multiple foreground ANSI color codes should only add a single class.');
				expect(adv8BitSimple.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
				//color is theme based, so we can't check what it should be but we know it should NOT BE 101,102,103 anymore
				expectInlineColor(adv8BitSimple, 'foreground', new RGBA(101, 102, 103), 'SHOULD NOT LONGER BE 24-bit RGBA ANSI color code (101,102,103) after simple color change.', false);
			},
			(adv24BitAgain) => {
				expect.strictEqual(1, adv24BitAgain.classes.length, 'Multiple foreground ANSI color codes should only add a single class.');
				expect(adv24BitAgain.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
				expectInlineColor(adv24BitAgain, 'foreground', new RGBA(104, 105, 106), '24-bit RGBA ANSI color code (104,105,106) should add matching color inline style.');
			},
			(adv8BitAdvanced) => {
				expect.strictEqual(1, adv8BitAdvanced.classes.length, 'Multiple foreground ANSI color codes should only add a single class.');
				expect(adv8BitAdvanced.classes.contains('ansi-foreground-colored'), 'Foreground ANSI color codes should add custom foreground color class.');
				// color should NO LONGER BE 104,105,106
				expectInlineColor(adv8BitAdvanced, 'foreground', new RGBA(104, 105, 106), 'SHOULD NOT LONGER BE 24-bit RGBA ANSI color code (104,105,106) after advanced color change.', false);
			}
		], 5);

	});

	/// 
	/// expect that the provided ANSI sequence exactly matches the text content of the resulting
	/// {@link HTMLSpanElement}.
	/// 
	/// @param sequence The ANSI sequence to verify.
	/// 
	function expectSequencestrictEqualToContent(sequence: string): void {
		const child: HTMLSpanElement = getSequenceOutput(sequence);
		expect(child.textContent == sequence);
	}

	test('Invalid codes treated as regular text', () => {

		// Individual components of ANSI code start are printed
		expectSequencestrictEqualToContent('\u001B');
		expectSequencestrictEqualToContent('[');

		// Unsupported sequence prints both characters
		expectSequencestrictEqualToContent('\u001B[');

		// Random strings are displayed properly
		for (let i = 0; i < 50; i++) {
			const uuid: string = generateUuid();
			expectSequencestrictEqualToContent(uuid);
		}

	});

	/// 
	/// expect that a given ANSI sequence maintains added content following the ANSI code, and that
	/// the expression itself is thrown away.
	/// 
	/// @param sequence The ANSI sequence to verify. The provided sequence should contain ANSI codes
	/// only, and should not include actual text content as it is provided by this function.
	/// 
	function expectEmptyOutput(sequence: string) {
		const child: HTMLSpanElement = getSequenceOutput(sequence + 'content');
		expect.strictEqual('content', child.textContent);
		expect.strictEqual(0, child.classes.length);
	}

	test('Empty sequence output', () => {

		const sequences: string[] = [
			// No colour codes
			'',
			'\u001B[;m',
			'\u001B[1;;m',
			'\u001B[m',
			'\u001B[99m'
		];

		sequences.forEach(sequence => {
			expectEmptyOutput(sequence);
		});

		// Check other possible ANSI terminators
		const terminators: string[] = 'ABCDHIJKfhmpsu'.split('');

		terminators.forEach(terminator => {
			expectEmptyOutput('\u001B[content' + terminator);
		});

	});

	test('AnsiConsoleHandler.calcAnsi8bitColor', () => {
		// Invalid values
		// Negative (below range), simple range, decimals
		for (let i = -10; i <= 15; i += 0.5) {
			expect(AnsiConsoleHandler.calcAnsi8bitColor(i) == null, 'Values less than 16 passed to AnsiConsoleHandler.calcAnsi8bitColor should return null.');
		}
		// In-range range decimals
		for (let i = 16.5; i < 254; i += 1) {
			expect(AnsiConsoleHandler.calcAnsi8bitColor(i) == null, 'Floats passed to AnsiConsoleHandler.calcAnsi8bitColor should return null.');
		}
		// Above range
		for (let i = 256; i < 300; i += 0.5) {
			expect(AnsiConsoleHandler.calcAnsi8bitColor(i) == null, 'Values grather than 255 passed to AnsiConsoleHandler.calcAnsi8bitColor should return null.');
		}

		// All valid colors
		for (let red = 0; red <= 5; red++) {
			for (let green = 0; green <= 5; green++) {
				for (let blue = 0; blue <= 5; blue++) {
					const colorOut: any = AnsiConsoleHandler.calcAnsi8bitColor(16 + red * 36 + green * 6 + blue);
					expect(colorOut.r == Math.round(red * (255 / 5)), 'Incorrect red value encountered for color');
					expect(colorOut.g == Math.round(green * (255 / 5)), 'Incorrect green value encountered for color');
					expect(colorOut.b == Math.round(blue * (255 / 5)), 'Incorrect balue value encountered for color');
				}
			}
		}

		// All grays
		for (let i = 232; i <= 255; i++) {
			const grayOut: any = AnsiConsoleHandler.calcAnsi8bitColor(i);
			expect(grayOut.r == grayOut.g);
			expect(grayOut.r == grayOut.b);
			expect(grayOut.r == Math.round((i - 232) / 23 * 255));
		}
	});

});


*/

