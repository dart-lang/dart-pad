import 'dart:async';
import 'dart:io';

import 'package:dartpad_shared/model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logging/logging.dart';

final _logger = Logger('gen-ai');

// TODO (csells): restrict packages to only those available in Dartpad
// TODO: parameterize by Dart vs. Flutter
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
          systemInstruction: Content.text('''
You are a Dart and Flutter expert. You will be given an error message at a
specific line and column in provided Dart source code. Please fix the code and
return it in it's entirety. The response should be the same program as the input
with the error fixed. The response should come back as raw code and not in a
Markdown code block.
'''),
        )
      : null;

  Stream<String> suggestFix({
    required String message,
    required int line,
    required int column,
    required String source,
  }) async* {
    _checkCanAI();
    assert(_fixModel != null);

    final prompt = '''
error message: $message
line: $line
column: $column
source code:
$source
''';
    final stream = _fixModel!.generateContentStream([Content.text(prompt)]);
    yield* cleanCode(_textOnly(stream));
  }

  late final _newCodeModel = _canGenAI
      ? GenerativeModel(
          apiKey: _geminiApiKey!,
          model: _geminiModel,
          systemInstruction: Content.text('''
You are a Dart and Flutter expert. You will be given a description of a Flutter
program. Please generate a Flutter program that satisfies the description.
The response should be a complete Flutter program. The response should come
back as raw code and not in a Markdown code block.
'''),
        )
      : null;

  Stream<String> generateCode({
    required String prompt,
    required List<Attachment> attachments,
  }) async* {
    _checkCanAI();
    assert(_newCodeModel != null);
    final logger = Logger('generateCode');
    logger.info('Generating code for prompt: $prompt');
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
          systemInstruction: Content.text('''
You are a Dart and Flutter expert. You will be given an existing Flutter program
and a description of a change to be made to it. Please generate an updated
Flutter program that satisfies the description.
The response should be a complete Flutter program. The response should come
back as raw code and not in a Markdown code block.
'''),
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
existing code:
$source

change description:
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
