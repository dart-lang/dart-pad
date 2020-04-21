///
//  Generated code. Do not modify.
//  source: protos/dart_services.proto
//
// @dart = 2.3
// ignore_for_file: camel_case_types,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type

const CompileRequest$json = {
  '1': 'CompileRequest',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
    {'1': 'returnSourceMap', '3': 2, '4': 1, '5': 8, '10': 'returnSourceMap'},
  ],
};

const CompileDDCRequest$json = {
  '1': 'CompileDDCRequest',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
  ],
};

const SourceRequest$json = {
  '1': 'SourceRequest',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
  ],
};

const AnalysisResults$json = {
  '1': 'AnalysisResults',
  '2': [
    {
      '1': 'issues',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.AnalysisIssue',
      '10': 'issues'
    },
    {'1': 'packageImports', '3': 2, '4': 3, '5': 9, '10': 'packageImports'},
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const AnalysisIssue$json = {
  '1': 'AnalysisIssue',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'line', '3': 2, '4': 1, '5': 5, '10': 'line'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {'1': 'sourceName', '3': 4, '4': 1, '5': 9, '10': 'sourceName'},
    {'1': 'hasFixes', '3': 5, '4': 1, '5': 8, '10': 'hasFixes'},
    {'1': 'charStart', '3': 6, '4': 1, '5': 5, '10': 'charStart'},
    {'1': 'charLength', '3': 7, '4': 1, '5': 5, '10': 'charLength'},
  ],
};

const VersionRequest$json = {
  '1': 'VersionRequest',
};

const CompileResponse$json = {
  '1': 'CompileResponse',
  '2': [
    {'1': 'result', '3': 1, '4': 1, '5': 9, '10': 'result'},
    {'1': 'sourceMap', '3': 2, '4': 1, '5': 9, '10': 'sourceMap'},
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const CompileDDCResponse$json = {
  '1': 'CompileDDCResponse',
  '2': [
    {'1': 'result', '3': 1, '4': 1, '5': 9, '10': 'result'},
    {'1': 'modulesBaseUrl', '3': 2, '4': 1, '5': 9, '10': 'modulesBaseUrl'},
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const DocumentResponse$json = {
  '1': 'DocumentResponse',
  '2': [
    {
      '1': 'info',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.DocumentResponse.InfoEntry',
      '10': 'info'
    },
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
  '3': [DocumentResponse_InfoEntry$json],
};

const DocumentResponse_InfoEntry$json = {
  '1': 'InfoEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

const CompleteResponse$json = {
  '1': 'CompleteResponse',
  '2': [
    {
      '1': 'replacementOffset',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'replacementOffset'
    },
    {
      '1': 'replacementLength',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'replacementLength'
    },
    {
      '1': 'completions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.Completion',
      '10': 'completions'
    },
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const Completion$json = {
  '1': 'Completion',
  '2': [
    {
      '1': 'completion',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.Completion.CompletionEntry',
      '10': 'completion'
    },
  ],
  '3': [Completion_CompletionEntry$json],
};

const Completion_CompletionEntry$json = {
  '1': 'CompletionEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

const FixesResponse$json = {
  '1': 'FixesResponse',
  '2': [
    {
      '1': 'fixes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.ProblemAndFixes',
      '10': 'fixes'
    },
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const ProblemAndFixes$json = {
  '1': 'ProblemAndFixes',
  '2': [
    {
      '1': 'fixes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.CandidateFix',
      '10': 'fixes'
    },
    {'1': 'problemMessage', '3': 2, '4': 1, '5': 9, '10': 'problemMessage'},
    {'1': 'offset', '3': 3, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'length', '3': 4, '4': 1, '5': 5, '10': 'length'},
  ],
};

const CandidateFix$json = {
  '1': 'CandidateFix',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'edits',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.SourceEdit',
      '10': 'edits'
    },
    {'1': 'selectionOffset', '3': 3, '4': 1, '5': 5, '10': 'selectionOffset'},
    {
      '1': 'linkedEditGroups',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.LinkedEditGroup',
      '10': 'linkedEditGroups'
    },
  ],
};

const SourceEdit$json = {
  '1': 'SourceEdit',
  '2': [
    {'1': 'offset', '3': 1, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'length', '3': 2, '4': 1, '5': 5, '10': 'length'},
    {'1': 'replacement', '3': 3, '4': 1, '5': 9, '10': 'replacement'},
  ],
};

const LinkedEditGroup$json = {
  '1': 'LinkedEditGroup',
  '2': [
    {'1': 'positions', '3': 1, '4': 3, '5': 5, '10': 'positions'},
    {'1': 'length', '3': 2, '4': 1, '5': 5, '10': 'length'},
    {
      '1': 'suggestions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.LinkedEditSuggestion',
      '10': 'suggestions'
    },
  ],
};

const LinkedEditSuggestion$json = {
  '1': 'LinkedEditSuggestion',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
  ],
};

const FormatResponse$json = {
  '1': 'FormatResponse',
  '2': [
    {'1': 'newString', '3': 1, '4': 1, '5': 9, '10': 'newString'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const AssistsResponse$json = {
  '1': 'AssistsResponse',
  '2': [
    {
      '1': 'assists',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.dart_services.api.CandidateFix',
      '10': 'assists'
    },
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const VersionResponse$json = {
  '1': 'VersionResponse',
  '2': [
    {'1': 'sdkVersion', '3': 1, '4': 1, '5': 9, '10': 'sdkVersion'},
    {'1': 'sdkVersionFull', '3': 2, '4': 1, '5': 9, '10': 'sdkVersionFull'},
    {'1': 'runtimeVersion', '3': 3, '4': 1, '5': 9, '10': 'runtimeVersion'},
    {'1': 'appEngineVersion', '3': 4, '4': 1, '5': 9, '10': 'appEngineVersion'},
    {'1': 'servicesVersion', '3': 5, '4': 1, '5': 9, '10': 'servicesVersion'},
    {'1': 'flutterVersion', '3': 6, '4': 1, '5': 9, '10': 'flutterVersion'},
    {
      '1': 'flutterDartVersion',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'flutterDartVersion'
    },
    {
      '1': 'flutterDartVersionFull',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'flutterDartVersionFull'
    },
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const BadRequest$json = {
  '1': 'BadRequest',
  '2': [
    {
      '1': 'error',
      '3': 99,
      '4': 1,
      '5': 11,
      '6': '.dart_services.api.ErrorMessage',
      '10': 'error'
    },
  ],
};

const ErrorMessage$json = {
  '1': 'ErrorMessage',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};
