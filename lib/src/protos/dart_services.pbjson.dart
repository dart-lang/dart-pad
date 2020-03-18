///
//  Generated code. Do not modify.
//  source: protos/dart_services.proto
//
// @dart = 2.3
// ignore_for_file: camel_case_types,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type

const CompileRequest$json = const {
  '1': 'CompileRequest',
  '2': const [
    const {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
    const {'1': 'returnSourceMap', '3': 2, '4': 1, '5': 8, '10': 'returnSourceMap'},
  ],
};

const SourceRequest$json = const {
  '1': 'SourceRequest',
  '2': const [
    const {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
    const {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
  ],
};

const AnalysisResults$json = const {
  '1': 'AnalysisResults',
  '2': const [
    const {'1': 'issues', '3': 1, '4': 3, '5': 11, '6': '.dart_services.api.AnalysisIssue', '10': 'issues'},
    const {'1': 'packageImports', '3': 2, '4': 3, '5': 9, '10': 'packageImports'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const AnalysisIssue$json = const {
  '1': 'AnalysisIssue',
  '2': const [
    const {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    const {'1': 'line', '3': 2, '4': 1, '5': 5, '10': 'line'},
    const {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    const {'1': 'sourceName', '3': 4, '4': 1, '5': 9, '10': 'sourceName'},
    const {'1': 'hasFixes', '3': 5, '4': 1, '5': 8, '10': 'hasFixes'},
    const {'1': 'charStart', '3': 6, '4': 1, '5': 5, '10': 'charStart'},
    const {'1': 'charLength', '3': 7, '4': 1, '5': 5, '10': 'charLength'},
  ],
};

const VersionRequest$json = const {
  '1': 'VersionRequest',
};

const CompileResponse$json = const {
  '1': 'CompileResponse',
  '2': const [
    const {'1': 'result', '3': 1, '4': 1, '5': 9, '10': 'result'},
    const {'1': 'sourceMap', '3': 2, '4': 1, '5': 9, '10': 'sourceMap'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const CompileDDCResponse$json = const {
  '1': 'CompileDDCResponse',
  '2': const [
    const {'1': 'result', '3': 1, '4': 1, '5': 9, '10': 'result'},
    const {'1': 'modulesBaseUrl', '3': 2, '4': 1, '5': 9, '10': 'modulesBaseUrl'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const DocumentResponse$json = const {
  '1': 'DocumentResponse',
  '2': const [
    const {'1': 'info', '3': 1, '4': 3, '5': 11, '6': '.dart_services.api.DocumentResponse.InfoEntry', '10': 'info'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
  '3': const [DocumentResponse_InfoEntry$json],
};

const DocumentResponse_InfoEntry$json = const {
  '1': 'InfoEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

const CompleteResponse$json = const {
  '1': 'CompleteResponse',
  '2': const [
    const {'1': 'replacementOffset', '3': 1, '4': 1, '5': 5, '10': 'replacementOffset'},
    const {'1': 'replacementLength', '3': 2, '4': 1, '5': 5, '10': 'replacementLength'},
    const {'1': 'completions', '3': 3, '4': 3, '5': 11, '6': '.dart_services.api.Completion', '10': 'completions'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const Completion$json = const {
  '1': 'Completion',
  '2': const [
    const {'1': 'completion', '3': 1, '4': 3, '5': 11, '6': '.dart_services.api.Completion.CompletionEntry', '10': 'completion'},
  ],
  '3': const [Completion_CompletionEntry$json],
};

const Completion_CompletionEntry$json = const {
  '1': 'CompletionEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

const FixesResponse$json = const {
  '1': 'FixesResponse',
  '2': const [
    const {'1': 'fixes', '3': 1, '4': 3, '5': 11, '6': '.dart_services.api.ProblemAndFixes', '10': 'fixes'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const ProblemAndFixes$json = const {
  '1': 'ProblemAndFixes',
  '2': const [
    const {'1': 'fixes', '3': 1, '4': 3, '5': 11, '6': '.dart_services.api.CandidateFix', '10': 'fixes'},
    const {'1': 'problemMessage', '3': 2, '4': 1, '5': 9, '10': 'problemMessage'},
    const {'1': 'offset', '3': 3, '4': 1, '5': 5, '10': 'offset'},
    const {'1': 'length', '3': 4, '4': 1, '5': 5, '10': 'length'},
  ],
};

const CandidateFix$json = const {
  '1': 'CandidateFix',
  '2': const [
    const {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
    const {'1': 'edits', '3': 2, '4': 3, '5': 11, '6': '.dart_services.api.SourceEdit', '10': 'edits'},
    const {'1': 'selectionOffset', '3': 3, '4': 1, '5': 5, '10': 'selectionOffset'},
    const {'1': 'linkedEditGroups', '3': 4, '4': 3, '5': 11, '6': '.dart_services.api.LinkedEditGroup', '10': 'linkedEditGroups'},
  ],
};

const SourceEdit$json = const {
  '1': 'SourceEdit',
  '2': const [
    const {'1': 'offset', '3': 1, '4': 1, '5': 5, '10': 'offset'},
    const {'1': 'length', '3': 2, '4': 1, '5': 5, '10': 'length'},
    const {'1': 'replacement', '3': 3, '4': 1, '5': 9, '10': 'replacement'},
  ],
};

const LinkedEditGroup$json = const {
  '1': 'LinkedEditGroup',
  '2': const [
    const {'1': 'positions', '3': 1, '4': 3, '5': 5, '10': 'positions'},
    const {'1': 'length', '3': 2, '4': 1, '5': 5, '10': 'length'},
    const {'1': 'suggestions', '3': 3, '4': 3, '5': 11, '6': '.dart_services.api.LinkedEditSuggestion', '10': 'suggestions'},
  ],
};

const LinkedEditSuggestion$json = const {
  '1': 'LinkedEditSuggestion',
  '2': const [
    const {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
    const {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
  ],
};

const FormatResponse$json = const {
  '1': 'FormatResponse',
  '2': const [
    const {'1': 'newString', '3': 1, '4': 1, '5': 9, '10': 'newString'},
    const {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const AssistsResponse$json = const {
  '1': 'AssistsResponse',
  '2': const [
    const {'1': 'assists', '3': 1, '4': 3, '5': 11, '6': '.dart_services.api.CandidateFix', '10': 'assists'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const VersionResponse$json = const {
  '1': 'VersionResponse',
  '2': const [
    const {'1': 'sdkVersion', '3': 1, '4': 1, '5': 9, '10': 'sdkVersion'},
    const {'1': 'sdkVersionFull', '3': 2, '4': 1, '5': 9, '10': 'sdkVersionFull'},
    const {'1': 'runtimeVersion', '3': 3, '4': 1, '5': 9, '10': 'runtimeVersion'},
    const {'1': 'appEngineVersion', '3': 4, '4': 1, '5': 9, '10': 'appEngineVersion'},
    const {'1': 'servicesVersion', '3': 5, '4': 1, '5': 9, '10': 'servicesVersion'},
    const {'1': 'flutterVersion', '3': 6, '4': 1, '5': 9, '10': 'flutterVersion'},
    const {'1': 'flutterDartVersion', '3': 7, '4': 1, '5': 9, '10': 'flutterDartVersion'},
    const {'1': 'flutterDartVersionFull', '3': 8, '4': 1, '5': 9, '10': 'flutterDartVersionFull'},
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const BadRequest$json = const {
  '1': 'BadRequest',
  '2': const [
    const {'1': 'error', '3': 99, '4': 1, '5': 11, '6': '.dart_services.api.ErrorMessage', '10': 'error'},
  ],
};

const ErrorMessage$json = const {
  '1': 'ErrorMessage',
  '2': const [
    const {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

