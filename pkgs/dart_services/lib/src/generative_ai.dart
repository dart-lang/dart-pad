import 'dart:async';
import 'dart:io';

import 'package:dartpad_shared/model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logging/logging.dart';

import 'project_templates.dart';
import 'pub.dart';

final _logger = Logger('gen-ai');

class GenerativeAI {
  static const _apiKeyVarName = 'PK_GEMINI_API_KEY';
  static const _geminiModel = 'gemini-2.0-flash-exp';
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

  late final _fixModel = _canGenAI
      ? GenerativeModel(
          apiKey: _geminiApiKey!,
          model: _geminiModel,
          systemInstruction: _completeSystemInstructions(
            '''
You will be given an error message in provided Dart source code along with an
optional line and column number where the error appears. Please fix the code and
return it in it's entirety. The response should be the same program as the input
with the error fixed.
''',
          ),
        )
      : null;

  Stream<String> suggestFix({
    required String message,
    required int? line,
    required int? column,
    required String source,
  }) async* {
    _checkCanAI();
    assert(_fixModel != null);

    final prompt = '''
ERROR MESSAGE: $message
${line != null ? 'LINE: $line\n' : ''}
${column != null ? 'COLUMN: $column\n' : ''}
SOURCE CODE:
$source
''';
    final stream = _fixModel!.generateContentStream([Content.text(prompt)]);
    yield* cleanCode(_textOnly(stream));
  }

  late final _newCodeModel = _canGenAI
      ? GenerativeModel(
          apiKey: _geminiApiKey!,
          model: _geminiModel,
          systemInstruction: _completeSystemInstructions(
            '''
Please generate a Flutter program that satisfies the provided description.
''',
          ),
        )
      : null;

  Stream<String> generateCode({
    required String prompt,
    required List<Attachment> attachments,
  }) async* {
    _checkCanAI();
    assert(_newCodeModel != null);
    _logger.info('generateCode: Generating code for prompt: $prompt');
    final stream = _newCodeModel!.generateContentStream([
      Content.text(prompt),
      ...attachments.map((a) => Content.data(a.mimeType, a.bytes)),
    ]);
    yield* cleanCode(_textOnly(stream));
  }

  late final _updateCodeModel = _canGenAI
      ? GenerativeModel(
          apiKey: _geminiApiKey!,
          model: _geminiModel,
          systemInstruction: _completeSystemInstructions(
            '''
You will be given an existing Flutter program and a description of a change to
be made to it. Please generate an updated Flutter program that satisfies the
description.
''',
          ),
        )
      : null;

  Stream<String> updateCode({
    required String prompt,
    required String source,
    required List<Attachment> attachments,
  }) async* {
    _checkCanAI();
    assert(_updateCodeModel != null);
    final completedPrompt = '''
EXISTING SOURCE CODE:
$source

CHANGE DESCRIPTION:
$prompt
''';
    final stream = _updateCodeModel!.generateContentStream([
      Content.text(completedPrompt),
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
  static const endCodeBlock = '```';

  static Stream<String> cleanCode(Stream<String> stream) async* {
    var foundFirstLine = false;
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      // looking for the start of the code block (if there is one)
      if (!foundFirstLine) {
        buffer.write(chunk);
        if (chunk.contains('\n')) {
          foundFirstLine = true;
          final text = buffer.toString().replaceFirst(startCodeBlock, '');
          buffer.clear();
          if (text.isNotEmpty) yield text;
          continue;
        }

        // still looking for the start of the first line
        continue;
      }

      // looking for the end of the code block (if there is one)
      assert(foundFirstLine);
      String processedChunk;
      if (chunk.endsWith(endCodeBlock)) {
        processedChunk = chunk.substring(0, chunk.length - endCodeBlock.length);
      } else if (chunk.endsWith('$endCodeBlock\n')) {
        processedChunk =
            '${chunk.substring(0, chunk.length - endCodeBlock.length - 1)}\n';
      } else {
        processedChunk = chunk;
      }

      if (processedChunk.isNotEmpty) yield processedChunk;
    }

    // if we're still in the first line, yield it
    if (buffer.isNotEmpty) yield buffer.toString();
  }
}

Content _completeSystemInstructions(String modelSpecificInstructions) {
  final allowedPackages = _allowedPackages();
  return Content.text('''
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

1. PRD: plan how to build a rich UI that fully satisfies the user's needs.
2. APP_PRODUCTION: integrate all the data from the previous steps and generate
   the principal widget for a Flutter app (the one that should be supplied as
   the home widget for MaterialApp), including the DATA_MODEL.
3. OUTPUT: output the finished application code only, with no explanations or
   commentary.

After each step in the process, integrate the information you have collected in
the previous step and move to the next step without stopping for verification
from the user. The only output shall be the result of the OUTPUT step.

# Requirements for Generating UI Code
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

ALLOWED PACKAGES:
Allowed packages which are used must be imported using the IMPORT given in order
for the app to build.

The following packages, at the specified versions, are allowed:
${allowedPackages.join('\n')}

$modelSpecificInstructions
''');
}

final _cachedAllowedPackages = List<String>.empty(growable: true);
List<String> _allowedPackages() {
  if (_cachedAllowedPackages.isEmpty) {
    final versions = getPackageVersions();
    for (final MapEntry(key: name, value: version) in versions.entries) {
      if (isSupportedPackage(name)) {
        _cachedAllowedPackages.add('$name: $version');
      }
    }
  }

  return _cachedAllowedPackages;
}
