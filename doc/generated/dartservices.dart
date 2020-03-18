// This is a generated file (see the discoveryapis_generator project).

// ignore_for_file: unnecessary_cast

library dart_services.dartservices.v1;

import 'dart:core' as core;
import 'dart:async' as async;
import 'dart:convert' as convert;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:http/http.dart' as http;

export 'package:_discoveryapis_commons/_discoveryapis_commons.dart'
    show ApiRequestError, DetailedApiRequestError;

const core.String USER_AGENT = 'dart-api-client dartservices/v1';

class DartservicesApi {
  final commons.ApiRequester _requester;

  DartservicesApi(http.Client client,
      {core.String rootUrl: "/",
      core.String servicePath: "api/dartservices/v1/"})
      : _requester =
            new commons.ApiRequester(client, rootUrl, servicePath, USER_AGENT);

  /// Analyze the given Dart source code and return any resulting analysis
  /// errors or warnings.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [AnalysisResults].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<AnalysisResults> analyze(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'analyze';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new AnalysisResults.fromJson(data));
  }

  /// Get assists for the given source code location.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [AssistsResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<AssistsResponse> assists(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'assists';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new AssistsResponse.fromJson(data));
  }

  /// Compile the given Dart source code and return the resulting JavaScript;
  /// this uses the dart2js compiler.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [CompileResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<CompileResponse> compile(CompileRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'compile';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new CompileResponse.fromJson(data));
  }

  /// Compile the given Dart source code and return the resulting JavaScript;
  /// this uses the DDC compiler.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [CompileDDCResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<CompileDDCResponse> compileDDC(CompileRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'compileDDC';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new CompileDDCResponse.fromJson(data));
  }

  /// Get the valid code completion results for the given offset.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [CompleteResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<CompleteResponse> complete(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'complete';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new CompleteResponse.fromJson(data));
  }

  /// Return the relevant dartdoc information for the element at the given
  /// offset.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [DocumentResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<DocumentResponse> document(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'document';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new DocumentResponse.fromJson(data));
  }

  /// Get any quick fixes for the given source code location.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [FixesResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<FixesResponse> fixes(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'fixes';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new FixesResponse.fromJson(data));
  }

  /// Format the given Dart source code and return the results. If an offset is
  /// supplied in the request, the new position for that offset in the formatted
  /// code will be returned.
  ///
  /// [request] - The metadata request object.
  ///
  /// Request parameters:
  ///
  /// Completes with a [FormatResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<FormatResponse> format(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.json.encode((request).toJson());
    }

    _url = 'format';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new FormatResponse.fromJson(data));
  }

  /// Return the current SDK version for DartServices.
  ///
  /// Request parameters:
  ///
  /// Completes with a [VersionResponse].
  ///
  /// Completes with a [commons.ApiRequestError] if the API endpoint returned an
  /// error.
  ///
  /// If the used [http.Client] completes with an error when making a REST call,
  /// this method will complete with the same error.
  async.Future<VersionResponse> version() {
    var _url = null;
    var _queryParams = new core.Map<core.String, core.List<core.String>>();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    _url = 'version';

    var _response = _requester.request(_url, "GET",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new VersionResponse.fromJson(data));
  }
}

class AnalysisIssue {
  core.int charLength;
  core.int charStart;
  core.bool hasFixes;
  core.String kind;
  core.int line;
  core.String message;
  core.String sourceName;

  AnalysisIssue();

  AnalysisIssue.fromJson(core.Map _json) {
    if (_json.containsKey("charLength")) {
      charLength = _json["charLength"];
    }
    if (_json.containsKey("charStart")) {
      charStart = _json["charStart"];
    }
    if (_json.containsKey("hasFixes")) {
      hasFixes = _json["hasFixes"];
    }
    if (_json.containsKey("kind")) {
      kind = _json["kind"];
    }
    if (_json.containsKey("line")) {
      line = _json["line"];
    }
    if (_json.containsKey("message")) {
      message = _json["message"];
    }
    if (_json.containsKey("sourceName")) {
      sourceName = _json["sourceName"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (charLength != null) {
      _json["charLength"] = charLength;
    }
    if (charStart != null) {
      _json["charStart"] = charStart;
    }
    if (hasFixes != null) {
      _json["hasFixes"] = hasFixes;
    }
    if (kind != null) {
      _json["kind"] = kind;
    }
    if (line != null) {
      _json["line"] = line;
    }
    if (message != null) {
      _json["message"] = message;
    }
    if (sourceName != null) {
      _json["sourceName"] = sourceName;
    }
    return _json;
  }
}

class AnalysisResults {
  core.List<AnalysisIssue> issues;

  /// The package imports parsed from the source.
  core.List<core.String> packageImports;

  AnalysisResults();

  AnalysisResults.fromJson(core.Map _json) {
    if (_json.containsKey("issues")) {
      issues = (_json["issues"] as core.List)
          .map<AnalysisIssue>((value) => new AnalysisIssue.fromJson(value))
          .toList();
    }
    if (_json.containsKey("packageImports")) {
      packageImports =
          (_json["packageImports"] as core.List).cast<core.String>();
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (issues != null) {
      _json["issues"] = issues.map((value) => (value).toJson()).toList();
    }
    if (packageImports != null) {
      _json["packageImports"] = packageImports;
    }
    return _json;
  }
}

class AssistsResponse {
  core.List<CandidateFix> assists;

  AssistsResponse();

  AssistsResponse.fromJson(core.Map _json) {
    if (_json.containsKey("assists")) {
      assists = (_json["assists"] as core.List)
          .map<CandidateFix>((value) => new CandidateFix.fromJson(value))
          .toList();
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (assists != null) {
      _json["assists"] = assists.map((value) => (value).toJson()).toList();
    }
    return _json;
  }
}

class CandidateFix {
  core.List<SourceEdit> edits;
  core.List<LinkedEditGroup> linkedEditGroups;
  core.String message;
  core.int selectionOffset;

  CandidateFix();

  CandidateFix.fromJson(core.Map _json) {
    if (_json.containsKey("edits")) {
      edits = (_json["edits"] as core.List)
          .map<SourceEdit>((value) => new SourceEdit.fromJson(value))
          .toList();
    }
    if (_json.containsKey("linkedEditGroups")) {
      linkedEditGroups = (_json["linkedEditGroups"] as core.List)
          .map<LinkedEditGroup>((value) => new LinkedEditGroup.fromJson(value))
          .toList();
    }
    if (_json.containsKey("message")) {
      message = _json["message"];
    }
    if (_json.containsKey("selectionOffset")) {
      selectionOffset = _json["selectionOffset"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (edits != null) {
      _json["edits"] = edits.map((value) => (value).toJson()).toList();
    }
    if (linkedEditGroups != null) {
      _json["linkedEditGroups"] =
          linkedEditGroups.map((value) => (value).toJson()).toList();
    }
    if (message != null) {
      _json["message"] = message;
    }
    if (selectionOffset != null) {
      _json["selectionOffset"] = selectionOffset;
    }
    return _json;
  }
}

class CompileDDCResponse {
  core.String modulesBaseUrl;
  core.String result;

  CompileDDCResponse();

  CompileDDCResponse.fromJson(core.Map _json) {
    if (_json.containsKey("modulesBaseUrl")) {
      modulesBaseUrl = _json["modulesBaseUrl"];
    }
    if (_json.containsKey("result")) {
      result = _json["result"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (modulesBaseUrl != null) {
      _json["modulesBaseUrl"] = modulesBaseUrl;
    }
    if (result != null) {
      _json["result"] = result;
    }
    return _json;
  }
}

class CompileRequest {
  /// Return the Dart to JS source map; optional (defaults to false).
  core.bool returnSourceMap;

  /// The Dart source.
  core.String source;

  CompileRequest();

  CompileRequest.fromJson(core.Map _json) {
    if (_json.containsKey("returnSourceMap")) {
      returnSourceMap = _json["returnSourceMap"];
    }
    if (_json.containsKey("source")) {
      source = _json["source"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (returnSourceMap != null) {
      _json["returnSourceMap"] = returnSourceMap;
    }
    if (source != null) {
      _json["source"] = source;
    }
    return _json;
  }
}

class CompileResponse {
  core.String result;
  core.String sourceMap;

  CompileResponse();

  CompileResponse.fromJson(core.Map _json) {
    if (_json.containsKey("result")) {
      result = _json["result"];
    }
    if (_json.containsKey("sourceMap")) {
      sourceMap = _json["sourceMap"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (result != null) {
      _json["result"] = result;
    }
    if (sourceMap != null) {
      _json["sourceMap"] = sourceMap;
    }
    return _json;
  }
}

class CompleteResponse {
  core.List<core.Map<core.String, core.String>> completions;

  /// The length of the text to be replaced.
  core.int replacementLength;

  /// The offset of the start of the text to be replaced.
  core.int replacementOffset;

  CompleteResponse();

  CompleteResponse.fromJson(core.Map _json) {
    if (_json.containsKey("completions")) {
      completions = (_json["completions"] as core.List)
          .map<core.Map<core.String, core.String>>(
              (value) => (value as core.Map).cast<core.String, core.String>())
          .toList();
    }
    if (_json.containsKey("replacementLength")) {
      replacementLength = _json["replacementLength"];
    }
    if (_json.containsKey("replacementOffset")) {
      replacementOffset = _json["replacementOffset"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (completions != null) {
      _json["completions"] = completions;
    }
    if (replacementLength != null) {
      _json["replacementLength"] = replacementLength;
    }
    if (replacementOffset != null) {
      _json["replacementOffset"] = replacementOffset;
    }
    return _json;
  }
}

class DocumentResponse {
  core.Map<core.String, core.String> info;

  DocumentResponse();

  DocumentResponse.fromJson(core.Map _json) {
    if (_json.containsKey("info")) {
      info = (_json["info"] as core.Map).cast<core.String, core.String>();
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (info != null) {
      _json["info"] = info;
    }
    return _json;
  }
}

class FixesResponse {
  core.List<ProblemAndFixes> fixes;

  FixesResponse();

  FixesResponse.fromJson(core.Map _json) {
    if (_json.containsKey("fixes")) {
      fixes = (_json["fixes"] as core.List)
          .map<ProblemAndFixes>((value) => new ProblemAndFixes.fromJson(value))
          .toList();
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (fixes != null) {
      _json["fixes"] = fixes.map((value) => (value).toJson()).toList();
    }
    return _json;
  }
}

class FormatResponse {
  /// The formatted source code.
  core.String newString;

  /// The (optional) new offset of the cursor; can be `null`.
  core.int offset;

  FormatResponse();

  FormatResponse.fromJson(core.Map _json) {
    if (_json.containsKey("newString")) {
      newString = _json["newString"];
    }
    if (_json.containsKey("offset")) {
      offset = _json["offset"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (newString != null) {
      _json["newString"] = newString;
    }
    if (offset != null) {
      _json["offset"] = offset;
    }
    return _json;
  }
}

class LinkedEditGroup {
  /// The length of the regions that should be edited simultaneously.
  core.int length;

  /// The positions of the regions that should be edited simultaneously.
  core.List<core.int> positions;

  /// Pre-computed suggestions for what every region might want to be changed
  /// to.
  core.List<LinkedEditSuggestion> suggestions;

  LinkedEditGroup();

  LinkedEditGroup.fromJson(core.Map _json) {
    if (_json.containsKey("length")) {
      length = _json["length"];
    }
    if (_json.containsKey("positions")) {
      positions = (_json["positions"] as core.List).cast<core.int>();
    }
    if (_json.containsKey("suggestions")) {
      suggestions = (_json["suggestions"] as core.List)
          .map<LinkedEditSuggestion>(
              (value) => new LinkedEditSuggestion.fromJson(value))
          .toList();
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (length != null) {
      _json["length"] = length;
    }
    if (positions != null) {
      _json["positions"] = positions;
    }
    if (suggestions != null) {
      _json["suggestions"] =
          suggestions.map((value) => (value).toJson()).toList();
    }
    return _json;
  }
}

class LinkedEditSuggestion {
  /// The kind of value being proposed.
  core.String kind;

  /// The value that could be used to replace all of the linked edit regions.
  core.String value;

  LinkedEditSuggestion();

  LinkedEditSuggestion.fromJson(core.Map _json) {
    if (_json.containsKey("kind")) {
      kind = _json["kind"];
    }
    if (_json.containsKey("value")) {
      value = _json["value"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (kind != null) {
      _json["kind"] = kind;
    }
    if (value != null) {
      _json["value"] = value;
    }
    return _json;
  }
}

class ProblemAndFixes {
  core.List<CandidateFix> fixes;
  core.int length;
  core.int offset;
  core.String problemMessage;

  ProblemAndFixes();

  ProblemAndFixes.fromJson(core.Map _json) {
    if (_json.containsKey("fixes")) {
      fixes = (_json["fixes"] as core.List)
          .map<CandidateFix>((value) => new CandidateFix.fromJson(value))
          .toList();
    }
    if (_json.containsKey("length")) {
      length = _json["length"];
    }
    if (_json.containsKey("offset")) {
      offset = _json["offset"];
    }
    if (_json.containsKey("problemMessage")) {
      problemMessage = _json["problemMessage"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (fixes != null) {
      _json["fixes"] = fixes.map((value) => (value).toJson()).toList();
    }
    if (length != null) {
      _json["length"] = length;
    }
    if (offset != null) {
      _json["offset"] = offset;
    }
    if (problemMessage != null) {
      _json["problemMessage"] = problemMessage;
    }
    return _json;
  }
}

class SourceEdit {
  core.int length;
  core.int offset;
  core.String replacement;

  SourceEdit();

  SourceEdit.fromJson(core.Map _json) {
    if (_json.containsKey("length")) {
      length = _json["length"];
    }
    if (_json.containsKey("offset")) {
      offset = _json["offset"];
    }
    if (_json.containsKey("replacement")) {
      replacement = _json["replacement"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (length != null) {
      _json["length"] = length;
    }
    if (offset != null) {
      _json["offset"] = offset;
    }
    if (replacement != null) {
      _json["replacement"] = replacement;
    }
    return _json;
  }
}

class SourceRequest {
  /// An optional offset into the source code.
  core.int offset;

  /// The Dart source.
  core.String source;

  SourceRequest();

  SourceRequest.fromJson(core.Map _json) {
    if (_json.containsKey("offset")) {
      offset = _json["offset"];
    }
    if (_json.containsKey("source")) {
      source = _json["source"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (offset != null) {
      _json["offset"] = offset;
    }
    if (source != null) {
      _json["source"] = source;
    }
    return _json;
  }
}

class VersionResponse {
  /// The App Engine version.
  core.String appEngineVersion;

  /// The Flutter SDK's Dart version.
  core.String flutterDartVersion;

  /// The Flutter SDK's full Dart version.
  core.String flutterDartVersionFull;

  /// The Flutter SDK version.
  core.String flutterVersion;

  /// The Dart SDK version that the server is running on. This will start with a
  /// semver string, and have a space and other build details appended.
  core.String runtimeVersion;

  /// The Dart SDK version that DartServices is compatible with. This will be a
  /// semver string.
  core.String sdkVersion;

  /// The full Dart SDK version that DartServices is compatible with.
  core.String sdkVersionFull;

  /// The dart-services backend version.
  core.String servicesVersion;

  VersionResponse();

  VersionResponse.fromJson(core.Map _json) {
    if (_json.containsKey("appEngineVersion")) {
      appEngineVersion = _json["appEngineVersion"];
    }
    if (_json.containsKey("flutterDartVersion")) {
      flutterDartVersion = _json["flutterDartVersion"];
    }
    if (_json.containsKey("flutterDartVersionFull")) {
      flutterDartVersionFull = _json["flutterDartVersionFull"];
    }
    if (_json.containsKey("flutterVersion")) {
      flutterVersion = _json["flutterVersion"];
    }
    if (_json.containsKey("runtimeVersion")) {
      runtimeVersion = _json["runtimeVersion"];
    }
    if (_json.containsKey("sdkVersion")) {
      sdkVersion = _json["sdkVersion"];
    }
    if (_json.containsKey("sdkVersionFull")) {
      sdkVersionFull = _json["sdkVersionFull"];
    }
    if (_json.containsKey("servicesVersion")) {
      servicesVersion = _json["servicesVersion"];
    }
  }

  core.Map<core.String, core.Object> toJson() {
    final core.Map<core.String, core.Object> _json =
        new core.Map<core.String, core.Object>();
    if (appEngineVersion != null) {
      _json["appEngineVersion"] = appEngineVersion;
    }
    if (flutterDartVersion != null) {
      _json["flutterDartVersion"] = flutterDartVersion;
    }
    if (flutterDartVersionFull != null) {
      _json["flutterDartVersionFull"] = flutterDartVersionFull;
    }
    if (flutterVersion != null) {
      _json["flutterVersion"] = flutterVersion;
    }
    if (runtimeVersion != null) {
      _json["runtimeVersion"] = runtimeVersion;
    }
    if (sdkVersion != null) {
      _json["sdkVersion"] = sdkVersion;
    }
    if (sdkVersionFull != null) {
      _json["sdkVersionFull"] = sdkVersionFull;
    }
    if (servicesVersion != null) {
      _json["servicesVersion"] = servicesVersion;
    }
    return _json;
  }
}
