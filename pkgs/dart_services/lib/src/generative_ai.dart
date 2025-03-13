// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:dartpad_shared/model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logging/logging.dart';

import 'project_templates.dart';
import 'pub.dart';

final _logger = Logger('gen-ai');

class GenerativeAI {
  static const _apiKeyVarName = 'GEMINI_API_KEY';
  static const _geminiModel = 'gemini-2.0-flash';
  late final String? _geminiApiKey;

  GenerativeAI() {
    final geminiApiKey = Platform.environment[_apiKeyVarName];
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      _logger.warning('$_apiKeyVarName not set; gen-ai features DISABLED');
    } else {
      _logger.info('$_apiKeyVarName set; gen-ai features ENABLED');
      _geminiApiKey = geminiApiKey;
    }
  }

  bool get _canGenAI => _geminiApiKey != null;

  late final _flutterFixModel =
      _canGenAI
          ? GenerativeModel(
            apiKey: _geminiApiKey!,
            model: _geminiModel,
            systemInstruction: _systemInstructions(AppType.flutter, '''
You will be given an error message in provided Flutter source code along with an
optional line and column number where the error appears. Please fix the code and
return it in it's entirety. The response should be the same program as the input
with the error fixed.
'''),
          )
          : null;

  late final _dartFixModel =
      _canGenAI
          ? GenerativeModel(
            apiKey: _geminiApiKey!,
            model: _geminiModel,
            systemInstruction: _systemInstructions(AppType.dart, '''
You will be given an error message in provided Dart source code along with an
optional line and column number where the error appears. Please fix the code and
return it in it's entirety. The response should be the same program as the input
with the error fixed.
'''),
          )
          : null;

  Stream<String> suggestFix({
    required AppType appType,
    required String message,
    required int? line,
    required int? column,
    required String source,
  }) async* {
    _checkCanAI();
    assert(_flutterFixModel != null);
    assert(_dartFixModel != null);

    final model = switch (appType) {
      AppType.flutter => _flutterFixModel!,
      AppType.dart => _dartFixModel!,
    };

    final prompt = '''
ERROR MESSAGE: $message
${line != null ? 'LINE: $line\n' : ''}
${column != null ? 'COLUMN: $column\n' : ''}
SOURCE CODE:
$source
''';
    final stream = model.generateContentStream([Content.text(prompt)]);
    yield* cleanCode(_textOnly(stream));
  }

  late final _newFlutterCodeModel =
      _canGenAI
          ? GenerativeModel(
            apiKey: _geminiApiKey!,
            model: _geminiModel,
            systemInstruction: _systemInstructions(AppType.flutter, '''
Generate a Flutter program that satisfies the provided description.
'''),
          )
          : null;

  late final _newDartCodeModel =
      _canGenAI
          ? GenerativeModel(
            apiKey: _geminiApiKey!,
            model: _geminiModel,
            systemInstruction: _systemInstructions(AppType.dart, '''
Generate a Dart program that satisfies the provided description.
'''),
          )
          : null;

  Stream<String> generateCode({
    required AppType appType,
    required String prompt,
    required List<Attachment> attachments,
  }) async* {
    _checkCanAI();
    assert(_newFlutterCodeModel != null);
    assert(_newDartCodeModel != null);

    final model = switch (appType) {
      AppType.flutter => _newFlutterCodeModel!,
      AppType.dart => _newDartCodeModel!,
    };

    final stream = model.generateContentStream([
      Content.text(prompt),
      ...attachments.map((a) => Content.data(a.mimeType, a.bytes)),
    ]);

    yield* cleanCode(_textOnly(stream));
  }

  late final _updateFlutterCodeModel =
      _canGenAI
          ? GenerativeModel(
            apiKey: _geminiApiKey!,
            model: _geminiModel,
            systemInstruction: _systemInstructions(AppType.flutter, '''
You will be given an existing Flutter program and a description of a change to
be made to it. Generate an updated Flutter program that satisfies the
description.
'''),
          )
          : null;

  late final _updateDartCodeModel =
      _canGenAI
          ? GenerativeModel(
            apiKey: _geminiApiKey!,
            model: _geminiModel,
            systemInstruction: _systemInstructions(AppType.dart, '''
You will be given an existing Dart program and a description of a change to
be made to it. Generate an updated Dart program that satisfies the
description.
'''),
          )
          : null;

  Stream<String> updateCode({
    required AppType appType,
    required String prompt,
    required String source,
    required List<Attachment> attachments,
  }) async* {
    _checkCanAI();
    assert(_updateFlutterCodeModel != null);
    assert(_updateDartCodeModel != null);

    final model = switch (appType) {
      AppType.flutter => _updateFlutterCodeModel!,
      AppType.dart => _updateDartCodeModel!,
    };

    final completePrompt = '''
EXISTING SOURCE CODE:
$source

CHANGE DESCRIPTION:
$prompt
''';

    final stream = model.generateContentStream([
      Content.text(completePrompt),
      ...attachments.map((a) => Content.data(a.mimeType, a.bytes)),
    ]);

    yield* cleanCode(_textOnly(stream));
  }

  void _checkCanAI() {
    if (!_canGenAI) throw Exception('Gemini API key not set');
  }

  static Stream<String> _textOnly(Stream<GenerateContentResponse> stream) =>
      stream
          .map((response) => response.text ?? '')
          .where((text) => text.isNotEmpty);

  static const startCodeBlock = '```dart\n';
  static const endCodeBlock = '\n```';

  /// Parses a stream of markdown text and yields only the content inside a
  /// ```dart ... ``` code block.
  ///
  /// Any text before the first occurrence of "```dart" is ignored. Once inside
  /// the code block, text is yielded until the closing "```" is encountered,
  /// at which point any remaining text is ignored.
  ///
  /// This parser works in a streaming manner and does not assume that the start
  /// or end markers are contained entirely in one chunk.
  static Stream<String> cleanCode(Stream<String> input) async* {
    const startMarker = '```dart\n';
    const endMarker = '```';
    final buffer = StringBuffer();
    var foundStart = false;
    var foundEnd = false;

    await for (final chunk in input) {
      if (foundEnd) continue;
      buffer.write(chunk);

      if (!foundStart) {
        final str = buffer.toString();
        final startIndex = str.indexOf(startMarker);
        if (startIndex == -1) continue;

        // Reset buffer to contain only content after the start marker
        // This handles cases where the marker is split across chunks
        buffer.clear();
        buffer.write(str.substring(startIndex + startMarker.length));
        foundStart = true;
      }

      assert(foundStart);
      assert(!foundEnd);

      final str = buffer.toString();
      final endIndex = str.indexOf(endMarker);
      foundEnd = endIndex != -1;

      // Only extract up to the end marker if found, otherwise yield the entire buffer
      // This handles partial code blocks that may be completed in future chunks
      final output = foundEnd ? str.substring(0, endIndex) : str;
      yield output;
      buffer.clear();
    }

    // Note: If stream ends without an end marker, we've already yielded all content
  }

  final _cachedAllowedPackages = <AppType, List<String>>{
    AppType.flutter: [],
    AppType.dart: [],
  };

  List<String> _allowedPackages(AppType appType) {
    final cachedList = _cachedAllowedPackages[appType]!;

    if (cachedList.isEmpty) {
      final versions = getPackageVersions();
      for (final MapEntry(key: name, value: version) in versions.entries) {
        final isSupported =
            appType == AppType.flutter
                ? isSupportedPackage(name)
                : isSupportedDartPackage(name);
        if (isSupported) cachedList.add('$name: $version');
      }
    }

    return cachedList;
  }

  Content _systemInstructions(
    AppType appType,
    String modelSpecificInstructions,
  ) {
    final instructions = _appInstructions[appType]!;
    final packageList = _allowedPackages(appType).map((p) => '- $p').join('\n');
    final footer = '''
ALLOWED PACKAGES
The following packages, at the specified versions, are allowed:
$packageList

If a package is not listed, it should not be used.
Package imports must appear at the top of the file before any other code.

$modelSpecificInstructions

Only output the Dart code for the program. Output the code wrapped in a
Markdown ```dart``` tag.
''';

    return Content.text('$instructions\n\n$footer');
  }

  static const Map<AppType, String> _appInstructions = {
    AppType.flutter: '''
You're an expert Flutter developer and UI designer creating Custom User
Interfaces: generated, bespoke, interactive interfaces created on-the-fly using
the Flutter SDK API. You will produce a professional, release-ready Flutter
application. All of the instructions below are required to be rigorously
followed.

Custom user interfaces add capabilities to apps so they can construct
just-in-time user interfaces that utilize design aesthetics, meaningful
information hierarchies, rich visual media, and allow for direct graphical
interactions.

Custom user interfaces shall be designed to help the user achieve a specific
goal, as expressed or implied by their prompt. They scale from simple text
widgets to rich interactive experiences. Custom user interfaces shall prioritize
clarity and ease of use. Include only the essential elements needed for the user
to achieve their goal, and present information in a clear and concise manner.
Design bespoke UIs to guide the user towards their desired outcome.

You're using the following process to systematically build the UI (each of the
numbered steps in the process is a separate part of the process, and can be
considered separate prompts; later steps have access to the output of the
earlier steps):

1. REQUIREMENTS: plan how to build a rich UI that fully satisfies the user's
   needs.
2. IMPLEMENTATION: integrate all the data from the previous steps and generate
   the principal widget for a Flutter app (the one that should be supplied as
   the home widget for MaterialApp), including the DATA_MODEL.
3. OUTPUT: output the finished application code only, with no explanations or
   commentary.

After each step in the process, integrate the information you have collected in
the previous step and move to the next step without stopping for verification
from the user. The only output shall be the result of the OUTPUT step.


### REQUIREMENTS FOR GENERATING UI CODE
All portions of the UI shall be implemented and functional, without TODO items
or placeholders.

All necessary UI component callbacks shall be hooked up appropriately and modify
state when the user interacts with them.

Initial UI data shall be initialized when constructing the data model, not in
the build function(s). Do not initialize to empty values if those are not valid
values in the UI.

The UI shall be "live" and update the data model each time a state change occurs
without requiring the user to "submit" state changes.

UI code shall be data-driven and independent of the specific data to be
displayed, so that any similar data could be substituted. For instance, if
choices or data are presented to the user, the choices or data shall not be hard
coded into the widgets, they shall be driven by the data model, so that the
contents may be replaced by a data model change.

Use appropriate IconData from Icons for icons in the UI. No emojis. Be careful
to allow the UI to adapt to differently sized devices without causing layout
errors or unusable UI. Do not make up icon names, use only icon names known to
exist.

VERY IMPORTANT: Do not include "Flutter Demo", "Flutter Demo Home Page" or other
demo-related text in the UI. You're not making a demo.

Use initializer lists when initializing values in a data model constructor.
Initializing members inside of the constructor body will cause a programming
error. There is no need to call super() without arguments. Initial values shall
always be valid values for the rest of the UI.

Import only actual packages like flutter and provider. Don't make up package
names. Any import statements shall only appear at the top of the file before any
other code.

Only import packages that are explicitly allowed. Packages which start with
"dart:" or "package:flutter/" are allowed, as are any packages specified in the
ALLOWED PACKAGES section below.

Whenever a state management solution is necessary, the provider package is
preferred, but only if provider is listed as an allowed package. Do not use a
state management solution for trivial state management, such as passing data to
a widget that is a child of the widget which provides the data.

Be sure to supply specific type arguments to all functions and constructors with
generic type arguments. This is especially important for Provider APIs and when
using the map function on Lists and other Iterables.

When a generic type argument has a type constraint, be sure that the value given
to the generic is of a compatible type. For example, when using a class defined
as ChangeNotifierProvider<T extends ChangeNotifier?>, make sure that the
provided data class is of type ChangeNotifier?.

Anything returned from the function given as the create argument of a
ChangeNotifierProvider<T extends ChangeNotifier?> must extend ChangeNotifier, or
it won't compile. The return type of the create function must be a
ChangeNotifier?, so the type of the value returned must extend ChangeNotifier.
If it returns a simple Object, it will not compile.

When using ChangeNotifierProvider, use the `builder` parameter rather than the
`child` parameter to ensure that the correct context is used. E.g.
   ```dart
      ChangeNotifierProvider<CatNameData>(
            create: (context) => CatNameData(),
            builder: (context, child) => SomeWidget()...
      )
   ```

When working with BuildContexts, be sure that the correct context variable is
being supplied as an argument. Take into account that the context given to a
build function does not contain the widgets inside of the build function.

When using TabBar and TabBarView, remember to specify a TabBarController using
the `controller` parameter in the constructor. For example:
  ```dart
  TabBar(
    controller: _tabController,
    tabs: myTabs,
  ),
  ```
The TabBarController must be owned by a StatefulWidget that implements
TickerProviderStateMixin. Remember to dispose of the TabBarController.

When creating callbacks, be sure that the nullability and type of the arguments,
and the return value, match the required signature of the callback. In
particular, remember that some widget callbacks must accept nullable parameters,
such as the DropdownButton's `onChanged` callback which must accept a nullable
String parameter: `void onChanged(String? value).

Referencing a value from a map e.g. `myMap['some_key']` will return a *nullable*
type which *nearly always* needs to be converted to a non-null type, e.g. via a
cast like `myMap['some_key']!` or with a fallback value as in
`myMap['some_key'] ?? fallback`.

When mapping an iterable, always specify the generic type of the result, e.g.
`someIterable.map<Widget>((item) => someLogicToCreateWidget(item))`.

If the Timer or Future types are referenced, the dart:async package must be
imported.

Create new widget classes instead of creating private build functions that
return Widgets. This is because private build functions that return Widgets can
reduce performance by causing excessive rebuilding of the UI, and can cause the
wrong context to be used.

Instance variables cannot be accessed from the initializer list of a
constructor. Only static variables can be accessed from the initializer list,
and only const members can be accessed from the initializer list of a const
constructor.

Do not refer to any local assets in the app, e.g. *never* use `Image.asset`. If
you want to use an image and don't have a URL, use `Image.network` with the
following placeholder URL:
https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg.

Make sure to check for layout overflows in the generated code and fix them
before returning the code.

The OUTPUT step shall emit only complete, compilable Flutter Dart code in a
single file which contains a complete app meant to be able to run immediately.
The output you will create is the contents of the main.dart file.

Make sure to take into account any attachments as part of the user's prompt.
''',
    AppType.dart: '''
You're an expert Dart developer specializing in writing efficient, idiomatic,
and production-ready Dart programs.  
You will produce professional, release-ready Dart applications. All of the
instructions below are required to be rigorously followed.

Dart applications include standalone scripts, backend services, CLI tools, and
other non-Flutter programs.  
They shall prioritize clarity, maintainability, and correctness. Your output
must be complete, fully functional, and immediately executable.

You're using the following process to systematically construct the Dart program
(each numbered step is a distinct part of the process):  

1. **PLANNING**: Determine how to fully implement the requested functionality in an idiomatic Dart program.
2. **IMPLEMENTATION**: Generate the entire Dart program, ensuring correctness, efficiency, and adherence to best practices.
3. **OUTPUT**: Output the finished program **only**, with no explanations or commentary.

After each step in the process, integrate the information from the previous step
and move forward without requiring user verification.  
The **only output** shall be the final, complete Dart program.


### REQUIREMENTS FOR GENERATING DART CODE
- All logic and functionality **must be fully implemented**—no TODOs,
placeholders, or incomplete functions.

- Programs must **follow Dart best practices**, including effective use of
`async/await`, null safety, and type inference.

- **Main execution should be structured properly**: The `main` function should
handle input/output in a clean and structured manner.

- **No Flutter or UI code is allowed**: The generated program **must not**
include any `flutter` imports, widget-based logic, or references to
`MaterialApp`, `Widgets`, or UI-related libraries.

- Programs must be **pure Dart**, using `dart:` libraries or explicitly allowed
third-party packages.

- **Use appropriate null safety practices**: Avoid unnecessary nullable types
and provide meaningful default values when needed.

- **Ensure correctness in type usage**: Use appropriate generic constraints and
avoid unnecessary dynamic typing.

- If the program requires **parsing, async tasks, or JSON handling**, use Dart's
built-in libraries like `dart:convert` and `dart:async` instead of external
dependencies unless specified.

- **Use efficient and idiomatic Dart patterns**: Prefer `map`/`reduce` for list
operations, and use extension methods where relevant.

- **Error handling must be robust**: If user input or file I/O is involved, wrap
potentially failing operations in `try/catch` blocks.

- **Programs must be designed for reusability**: Functions and classes should be
structured to allow modularity and extension without unnecessary global state.


### FINAL OUTPUT REQUIREMENT
- The **only** output shall be a **complete, compilable Dart program** in a
**single file** that runs immediately.

- Ensure that the generated program meets the functional requirements described
in the prompt.

- If any attachments are provided, they must be considered as part of the
prompt.


### INSTRUCTIONS FOR GENERATING CODE
**DO NOT** include Flutter-related imports, widgets, UI components, or anything
related to mobile app development.

You are generating a **pure Dart** program with a `main` function entry point.
''',
  };
}
