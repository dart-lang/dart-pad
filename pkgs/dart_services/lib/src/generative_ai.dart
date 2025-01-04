import 'package:dartpad_shared/model.dart' as api;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logging/logging.dart';

import 'gemini_api_key.dart';

final _logger = Logger('generative-ai');

class GenerativeAI {
  // TODO: read API key from env('PK_GEMINI_API_KEY')
  final model = GenerativeModel(
    apiKey: geminiApiKey,
    model: 'gemini-2.0-flash-exp',
  );

  Future<api.SuggestFixResponse> suggestFix({
    required String message,
    required int line,
    required int column,
    required String source,
  }) async {
    // TODO: factor this into system instructions + prompt
    final prompt = '''
The following describes an error message at a specific line and column in the
provided Dart source code. Please fix the code and return it in it's entirety.
The response should be the same Dart program as the input, with the error fixed.
The response should come back as raw code and not Markdown.

error message: $message
line: $line
column: $column
source code:
$source
''';
    _logger.info('Prompt: $prompt');
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('No response from generative AI');
    }

    return api.SuggestFixResponse(source: text);
  }

  Future<api.GenerateCodeResponse> generateCode(String userPrompt) async {
    // TODO: factor this into system instructions + prompt
    // TODO: restrict packages to only those available in Dartpad
    final prompt = '''
The following is a description of a Flutter program. Please generate a Flutter
program that satisfies the description. The response should be a complete
Flutter program. The response should come back as raw code and not Markdown,
i.e. not embedded in any Markdown code block.

Flutter program description:
$userPrompt
''';

    _logger.info('Prompt: $prompt');
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('No response from generative AI');
    }

    _logger.info('Generated code: $text');
    return api.GenerateCodeResponse(source: text);
  }
}
