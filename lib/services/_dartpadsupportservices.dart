// This is a generated file (see the discoveryapis_generator project).

library services.P_dartpadsupportservices.v1;

import 'dart:core' as core;
import 'dart:async' as async;
import 'dart:convert' as convert;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:http/http.dart' as http;

export 'package:_discoveryapis_commons/_discoveryapis_commons.dart'
    show ApiRequestError, DetailedApiRequestError;

const core.String USER_AGENT = 'dart-api-client _dartpadsupportservices/v1';

class P_dartpadsupportservicesApi {
  final commons.ApiRequester _requester;

  P_dartpadsupportservicesApi(http.Client client,
      {core.String rootUrl: "/",
      core.String servicePath: "api/_dartpadsupportservices/v1/"})
      : _requester =
            new commons.ApiRequester(client, rootUrl, servicePath, USER_AGENT);

  /**
   * Store a gist dataset to be retrieved.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [UuidContainer].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  async.Future<UuidContainer> export(PadSaveObject request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }

    _url = 'export';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new UuidContainer.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * Completes with a [UuidContainer].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  async.Future<UuidContainer> getUnusedMappingId() {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    _url = 'getUnusedMappingId';

    var _response = _requester.request(_url, "GET",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new UuidContainer.fromJson(data));
  }

  /**
   * Retrieve a stored gist data set.
   *
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [PadSaveObject].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  async.Future<PadSaveObject> pullExportContent(UuidContainer request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }

    _url = 'pullExportData';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new PadSaveObject.fromJson(data));
  }

  /**
   * Request parameters:
   *
   * [id] - Query parameter: 'id'.
   *
   * Completes with a [UuidContainer].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  async.Future<UuidContainer> retrieveGist({core.String id}) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (id != null) {
      _queryParams["id"] = [id];
    }

    _url = 'retrieveGist';

    var _response = _requester.request(_url, "GET",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new UuidContainer.fromJson(data));
  }

  /**
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [UuidContainer].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  async.Future<UuidContainer> storeGist(GistToInternalIdMapping request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }

    _url = 'storeGist';

    var _response = _requester.request(_url, "POST",
        body: _body,
        queryParams: _queryParams,
        uploadOptions: _uploadOptions,
        uploadMedia: _uploadMedia,
        downloadOptions: _downloadOptions);
    return _response.then((data) => new UuidContainer.fromJson(data));
  }
}

class GistToInternalIdMapping {
  core.String gistId;
  core.String internalId;

  GistToInternalIdMapping();

  GistToInternalIdMapping.fromJson(core.Map _json) {
    if (_json.containsKey("gistId")) {
      gistId = _json["gistId"];
    }
    if (_json.containsKey("internalId")) {
      internalId = _json["internalId"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (gistId != null) {
      _json["gistId"] = gistId;
    }
    if (internalId != null) {
      _json["internalId"] = internalId;
    }
    return _json;
  }
}

class PadSaveObject {
  core.String css;
  core.String dart;
  core.String html;
  core.String uuid;

  PadSaveObject();

  PadSaveObject.fromJson(core.Map _json) {
    if (_json.containsKey("css")) {
      css = _json["css"];
    }
    if (_json.containsKey("dart")) {
      dart = _json["dart"];
    }
    if (_json.containsKey("html")) {
      html = _json["html"];
    }
    if (_json.containsKey("uuid")) {
      uuid = _json["uuid"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (css != null) {
      _json["css"] = css;
    }
    if (dart != null) {
      _json["dart"] = dart;
    }
    if (html != null) {
      _json["html"] = html;
    }
    if (uuid != null) {
      _json["uuid"] = uuid;
    }
    return _json;
  }
}

class UuidContainer {
  core.String uuid;

  UuidContainer();

  UuidContainer.fromJson(core.Map _json) {
    if (_json.containsKey("uuid")) {
      uuid = _json["uuid"];
    }
  }

  core.Map toJson() {
    var _json = new core.Map();
    if (uuid != null) {
      _json["uuid"] = uuid;
    }
    return _json;
  }
}
