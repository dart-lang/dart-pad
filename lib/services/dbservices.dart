// This is a generated file (see the discoveryapis_generator project).

library helloworld.dbservices.v1;

import 'dart:async';
import 'dart:convert' as convert;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:http/http.dart' as http;

export 'package:_discoveryapis_commons/_discoveryapis_commons.dart' show
    ApiRequestError, DetailedApiRequestError;

const String USER_AGENT = 'dart-api-client dbservices/v1';

class DbservicesApi {

  final commons.ApiRequester _requester;

  //TODO: Figure out why /api/dbservices/v1/ no longer works
  DbservicesApi(http.Client client, {String rootUrl: "/", String servicePath: "dbservices/v1/"}) :
      _requester = new commons.ApiRequester(client, rootUrl, servicePath, USER_AGENT);

  /**
   * Request parameters:
   *
   * [key] - Query parameter: 'key'.
   *
   * Completes with a [DataSaveObject].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  Future<DataSaveObject> returnContent({String key}) {
    var _url = null;
    var _queryParams = new Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (key != null) {
      _queryParams["key"] = [key];
    }

    _url = 'return';

    var _response = _requester.request(_url,
                                       "GET",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new DataSaveObject.fromJson(data));
  }

  /**
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [KeyContainer].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  Future<KeyContainer> returnKey(DataSaveObject request) {
    var _url = null;
    var _queryParams = new Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode((request).toJson());
    }

    _url = 'export';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => new KeyContainer.fromJson(data));
  }

}



class DataSaveObject {
  String css;
  String dart;
  String html;

  DataSaveObject();

  DataSaveObject.fromJson(Map _json) {
    if (_json.containsKey("css")) {
      css = _json["css"];
    }
    if (_json.containsKey("dart")) {
      dart = _json["dart"];
    }
    if (_json.containsKey("html")) {
      html = _json["html"];
    }
  }

  Map toJson() {
    var _json = new Map();
    if (css != null) {
      _json["css"] = css;
    }
    if (dart != null) {
      _json["dart"] = dart;
    }
    if (html != null) {
      _json["html"] = html;
    }
    return _json;
  }
}

class KeyContainer {
  String key;

  KeyContainer();

  KeyContainer.fromJson(Map _json) {
    if (_json.containsKey("key")) {
      key = _json["key"];
    }
  }

  Map toJson() {
    var _json = new Map();
    if (key != null) {
      _json["key"] = key;
    }
    return _json;
  }
}
