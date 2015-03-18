library dartservices_clientlib.dartservices.v1;

import 'dart:core' as core;
import 'dart:collection' as collection;
import 'dart:async' as async;
import 'dart:convert' as convert;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

export 'package:_discoveryapis_commons/_discoveryapis_commons.dart' show
    ApiRequestError, DetailedApiRequestError;

const core.String USER_AGENT = 'dart-api-client dartservices/v1';

/** Not documented yet. */
class DartservicesApi {

  final commons.ApiRequester _requester;

  DartservicesApi(http.Client client, {core.String rootUrl: "http://localhost/", core.String servicePath: "api/dartservices/v1/"}) :
      _requester = new commons.ApiRequester(client, rootUrl, servicePath, USER_AGENT);

  /**
   * Not documented yet.
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
   * Not documented yet.
   *
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
   * Not documented yet.
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
  async.Future<CompileResponse> compile(SourceRequest request) {
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
   * Not documented yet.
   *
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
   * Not documented yet.
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
   * Not documented yet.
   *
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
   * Not documented yet.
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
   * Not documented yet.
   *
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

}



/** Not documented yet. */
class AnalysisIssue {
  /** Not documented yet. */
  core.int charLength;

  /** Not documented yet. */
  core.int charStart;

  /** Not documented yet. */
  core.String kind;

  /** Not documented yet. */
  core.int line;

  /** Not documented yet. */
  core.String location;

  /** Not documented yet. */
  core.String message;


  AnalysisIssue();

  AnalysisIssue.fromJson(core.Map _json) {
    if (_json.containsKey("charLength")) {
      charLength = _json["charLength"];
    }
    if (_json.containsKey("charStart")) {
      charStart = _json["charStart"];
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
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (charLength != null) {
      _json["charLength"] = charLength;
    }
    if (charStart != null) {
      _json["charStart"] = charStart;
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
    return _json;
  }
}


/** Not documented yet. */
class AnalysisResults {
  /** Not documented yet. */
  core.List<AnalysisIssue> issues;


  AnalysisResults();

  AnalysisResults.fromJson(core.Map _json) {
    if (_json.containsKey("issues")) {
      issues = _json["issues"].map((value) => new AnalysisIssue.fromJson(value)).toList();
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (issues != null) {
      _json["issues"] = issues.map((value) => (value).toJson()).toList();
    }
    return _json;
  }
}


/** Not documented yet. */
class CompileResponse {
  /** Not documented yet. */
  core.String result;


  CompileResponse();

  CompileResponse.fromJson(core.Map _json) {
    if (_json.containsKey("result")) {
      result = _json["result"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (result != null) {
      _json["result"] = result;
    }
    return _json;
  }
}


/** Not documented yet. */
class CompleteResponse {
  /** Not documented yet. */
  core.String result;


  CompleteResponse();

  CompleteResponse.fromJson(core.Map _json) {
    if (_json.containsKey("result")) {
      result = _json["result"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (result != null) {
      _json["result"] = result;
    }
    return _json;
  }
}


/** Not documented yet. */
class DocumentResponse {
  /** Not documented yet. */
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


/** Not documented yet. */
class SourceRequest {
  /** Not documented yet. */
  core.int offset;

  /** Not documented yet. */
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


