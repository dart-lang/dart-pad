// This is a generated file (see the discoveryapis_generator project).

library services.dartservices.v1;

import 'dart:core' as core;
//import 'dart:collection' as collection;
import 'dart:async' as async;
import 'dart:convert' as convert;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
//import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

export 'package:_discoveryapis_commons/_discoveryapis_commons.dart' show
    ApiRequestError, DetailedApiRequestError;

const core.String USER_AGENT = 'dart-api-client dartservices/v1';

class DartservicesApi {

  final commons.ApiRequester _requester;

  DartservicesApi(http.Client client, {core.String rootUrl: "/", core.String servicePath: "api/dartservices/v1/"}) :
      _requester = new commons.ApiRequester(client, rootUrl, servicePath, USER_AGENT);

  /**
   * Analyze the given Dart source code and return any resulting analysis errors
   * or warnings.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [AnalysisResults].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<AnalysisResults> analyze(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'analyze';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new AnalysisResults.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [source] - Query parameter: 'source'.
   *
   * Completes with a [AnalysisResults].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<AnalysisResults> analyzeGet({core.String source}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (source != null) {
      _queryParams["source"] = [source];
    }


    _url = 'analyze';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new AnalysisResults.fromJson(data));
  }

  /**
   * Analyze the given Dart source code and return any resulting analysis errors
   * or warnings.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [AnalysisResults].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<AnalysisResults> analyzeMulti(SourcesRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'analyzeMulti';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new AnalysisResults.fromJson(data));
  }

  /**
   * Compile the given Dart source code and return the resulting JavaScript.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [CompileResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<CompileResponse> compile(CompileRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'compile';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new CompileResponse.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [source] - Query parameter: 'source'.
   *
   * Completes with a [CompileResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<CompileResponse> compileGet({core.String source}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (source != null) {
      _queryParams["source"] = [source];
    }


    _url = 'compile';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new CompileResponse.fromJson(data));
  }

  /**
   * Get the valid code completion results for the given offset.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [CompleteResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<CompleteResponse> complete(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'complete';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new CompleteResponse.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [source] - Query parameter: 'source'.
   *
   * [offset] - Query parameter: 'offset'.
   *
   * Completes with a [CompleteResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<CompleteResponse> completeGet({core.String source, core.int offset}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (source != null) {
      _queryParams["source"] = [source];
    }
    if (offset != null) {
      _queryParams["offset"] = ["${offset}"];
    }


    _url = 'complete';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new CompleteResponse.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [name] - Query parameter: 'name'.
   *
   * Completes with a [CounterResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<CounterResponse> counterGet({core.String name}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (name != null) {
      _queryParams["name"] = [name];
    }


    _url = 'counter';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new CounterResponse.fromJson(data));
  }

  /**
   * Return the relevant dartdoc information for the element at the given
   * offset.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [DocumentResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<DocumentResponse> document(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'document';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new DocumentResponse.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [source] - Query parameter: 'source'.
   *
   * [offset] - Query parameter: 'offset'.
   *
   * Completes with a [DocumentResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<DocumentResponse> documentGet({core.String source, core.int offset}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (source != null) {
      _queryParams["source"] = [source];
    }
    if (offset != null) {
      _queryParams["offset"] = ["${offset}"];
    }


    _url = 'document';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new DocumentResponse.fromJson(data));
  }

  /**
   * Get any quick fixes for the given source code location.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [FixesResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<FixesResponse> fixes(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'fixes';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new FixesResponse.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [source] - Query parameter: 'source'.
   *
   * [offset] - Query parameter: 'offset'.
   *
   * Completes with a [FixesResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<FixesResponse> fixesGet({core.String source, core.int offset}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (source != null) {
      _queryParams["source"] = [source];
    }
    if (offset != null) {
      _queryParams["offset"] = ["${offset}"];
    }


    _url = 'fixes';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new FixesResponse.fromJson(data));
  }

  /**
   * Format the given Dart source code and return the results. If an offset is
   * supplied in the request, the new position for that offset in the formatted
   * code will be returned.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [FormatResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<FormatResponse> format(SourceRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }


    _url = 'format';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new FormatResponse.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [source] - Query parameter: 'source'.
   *
   * [offset] - Query parameter: 'offset'.
   *
   * Completes with a [FormatResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<FormatResponse> formatGet({core.String source, core.int offset}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (source != null) {
      _queryParams["source"] = [source];
    }
    if (offset != null) {
      _queryParams["offset"] = ["${offset}"];
    }


    _url = 'format';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new FormatResponse.fromJson(data));
  }

  /**
   * Return the current SDK version for DartServices.
   *
   * Request parameters:
   *
   * Completes with a [VersionResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method  will complete with the same error.
   */
  async.Future<VersionResponse> version() {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;



    _url = 'version';

    var _response = _requester.request(_url,
                                       "GET",
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

  /** deprecated - see `sourceName` */
  core.String location;

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
    if (_json.containsKey("location")) {
      location = _json["location"];
    }
    if (_json.containsKey("message")) {
      message = _json["message"];
    }
    if (_json.containsKey("sourceName")) {
      sourceName = _json["sourceName"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
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
    if (location != null) {
      _json["location"] = location;
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

  /** The package imports parsed from the source. */
  core.List<core.String> packageImports;

  /** The resolved imports - e.g. dart:async, dart:io, ... */
  core.List<core.String> resolvedImports;


  AnalysisResults();

  AnalysisResults.fromJson(core.Map _json) {
    if (_json.containsKey("issues")) {
      issues = _json["issues"].map((value) => new AnalysisIssue.fromJson(value)).toList();
    }
    if (_json.containsKey("packageImports")) {
      packageImports = _json["packageImports"];
    }
    if (_json.containsKey("resolvedImports")) {
      resolvedImports = _json["resolvedImports"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (issues != null) {
      _json["issues"] = issues.map((value) => (value).toJson()).toList();
    }
    if (packageImports != null) {
      _json["packageImports"] = packageImports;
    }
    if (resolvedImports != null) {
      _json["resolvedImports"] = resolvedImports;
    }
    return _json;
  }
}


class CandidateFix {
  core.List<SourceEdit> edits;

  core.String message;


  CandidateFix();

  CandidateFix.fromJson(core.Map _json) {
    if (_json.containsKey("edits")) {
      edits = _json["edits"].map((value) => new SourceEdit.fromJson(value)).toList();
    }
    if (_json.containsKey("message")) {
      message = _json["message"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (edits != null) {
      _json["edits"] = edits.map((value) => (value).toJson()).toList();
    }
    if (message != null) {
      _json["message"] = message;
    }
    return _json;
  }
}


class CompileRequest {
  /** Return the Dart to JS source map; optional (defaults to false). */
  core.bool returnSourceMap;

  /** The Dart source. */
  core.String source;

  /**
   * Compile to code with checked mode checks; optional (defaults to false).
   */
  core.bool useCheckedMode;


  CompileRequest();

  CompileRequest.fromJson(core.Map _json) {
    if (_json.containsKey("returnSourceMap")) {
      returnSourceMap = _json["returnSourceMap"];
    }
    if (_json.containsKey("source")) {
      source = _json["source"];
    }
    if (_json.containsKey("useCheckedMode")) {
      useCheckedMode = _json["useCheckedMode"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (returnSourceMap != null) {
      _json["returnSourceMap"] = returnSourceMap;
    }
    if (source != null) {
      _json["source"] = source;
    }
    if (useCheckedMode != null) {
      _json["useCheckedMode"] = useCheckedMode;
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

  core.Map toJson() {
    var _json = new core.Map();
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

  /** The length of the text to be replaced. */
  core.int replacementLength;

  /** The offset of the start of the text to be replaced. */
  core.int replacementOffset;


  CompleteResponse();

  CompleteResponse.fromJson(core.Map _json) {
    if (_json.containsKey("completions")) {
      completions = _json["completions"];
    }
    if (_json.containsKey("replacementLength")) {
      replacementLength = _json["replacementLength"];
    }
    if (_json.containsKey("replacementOffset")) {
      replacementOffset = _json["replacementOffset"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
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


class CounterResponse {
  core.int count;


  CounterResponse();

  CounterResponse.fromJson(core.Map _json) {
    if (_json.containsKey("count")) {
      count = _json["count"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (count != null) {
      _json["count"] = count;
    }
    return _json;
  }
}


class DocumentResponse {
  core.Map<core.String, core.String> info;


  DocumentResponse();

  DocumentResponse.fromJson(core.Map _json) {
    if (_json.containsKey("info")) {
      info = _json["info"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
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
      fixes = _json["fixes"].map((value) => new ProblemAndFixes.fromJson(value)).toList();
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (fixes != null) {
      _json["fixes"] = fixes.map((value) => (value).toJson()).toList();
    }
    return _json;
  }
}


class FormatResponse {
  /** The formatted source code. */
  core.String newString;

  /** The (optional) new offset of the cursor; can be `null`. */
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

  core.Map toJson() {
    var _json = new core.Map();
    if (newString != null) {
      _json["newString"] = newString;
    }
    if (offset != null) {
      _json["offset"] = offset;
    }
    return _json;
  }
}


class Location {
  core.String fullName;

  core.int offset;


  Location();

  Location.fromJson(core.Map _json) {
    if (_json.containsKey("fullName")) {
      fullName = _json["fullName"];
    }
    if (_json.containsKey("offset")) {
      offset = _json["offset"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (fullName != null) {
      _json["fullName"] = fullName;
    }
    if (offset != null) {
      _json["offset"] = offset;
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
      fixes = _json["fixes"].map((value) => new CandidateFix.fromJson(value)).toList();
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

  core.Map toJson() {
    var _json = new core.Map();
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

  core.Map toJson() {
    var _json = new core.Map();
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
  /** An optional offset into the source code. */
  core.int offset;

  /** The Dart source. */
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

  core.Map toJson() {
    var _json = new core.Map();
    if (offset != null) {
      _json["offset"] = offset;
    }
    if (source != null) {
      _json["source"] = source;
    }
    return _json;
  }
}


class SourcesRequest {
  /** An optional location in the source code. */
  Location location;

  /** Map of names to Sources. */
  core.Map<core.String, core.String> sources;


  SourcesRequest();

  SourcesRequest.fromJson(core.Map _json) {
    if (_json.containsKey("location")) {
      location = new Location.fromJson(_json["location"]);
    }
    if (_json.containsKey("sources")) {
      sources = _json["sources"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (location != null) {
      _json["location"] = (location).toJson();
    }
    if (sources != null) {
      _json["sources"] = sources;
    }
    return _json;
  }
}


class VersionResponse {
  /** The App Engine version. */
  core.String appEngineVersion;

  /**
   * The Dart SDK version that the server is running on. This will start with a
   * semver string, and have a space and other build details appended.
   */
  core.String runtimeVersion;

  /**
   * The Dart SDK version that DartServices is compatible with. This will be a
   * semver string.
   */
  core.String sdkVersion;

  /** The dart-services backend version. */
  core.String servicesVersion;


  VersionResponse();

  VersionResponse.fromJson(core.Map _json) {
    if (_json.containsKey("appEngineVersion")) {
      appEngineVersion = _json["appEngineVersion"];
    }
    if (_json.containsKey("runtimeVersion")) {
      runtimeVersion = _json["runtimeVersion"];
    }
    if (_json.containsKey("sdkVersion")) {
      sdkVersion = _json["sdkVersion"];
    }
    if (_json.containsKey("servicesVersion")) {
      servicesVersion = _json["servicesVersion"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (appEngineVersion != null) {
      _json["appEngineVersion"] = appEngineVersion;
    }
    if (runtimeVersion != null) {
      _json["runtimeVersion"] = runtimeVersion;
    }
    if (sdkVersion != null) {
      _json["sdkVersion"] = sdkVersion;
    }
    if (servicesVersion != null) {
      _json["servicesVersion"] = servicesVersion;
    }
    return _json;
  }
}
