// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.database;

import 'package:rpc/rpc.dart';
import 'dart:async';
import 'package:appengine/appengine.dart' as ae;
import 'package:gcloud/db.dart' as db;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart' as uuid_tools;

final Logger _logger = new Logger('dartpad_support_server');

// This class defines the interface that the server provides.
@ApiClass(name: '_dartpadsupportservices', version: 'v1')
class FileRelayServer {
  FileRelayServer() {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;
  }

  @ApiMethod(method: 'POST', path: 'export', description: 'Store a gist dataset to be retrieved.')
  Future<UuidContainer> export(PadSaveObject data) {
    _GaePadSaveObject record = new _GaePadSaveObject.fromDSO(data);
    String randomUuid = new uuid_tools.Uuid().v4();
    record.uuid = "${_computeSHA1(record)}-$randomUuid";
    db.dbService.commit(inserts: [record]).catchError((e) {
      _logger.severe("Error while recording export ${e}");
      throw e;
    });
    _logger.info("Recorded Export with ID ${record.uuid}");
    return new Future.value(new UuidContainer.fromUuid(record.uuid));
  }

  @ApiMethod(method: 'POST', path: 'pullExportData', description: 'Retrieve a stored gist data set.')
  Future<PadSaveObject> pullExportContent(UuidContainer uuidContainer) async {
    var database = ae.context.services.db;
    var query = database.query(_GaePadSaveObject)..filter('uuid =', uuidContainer.uuid);
    List result = await query.run().toList();
    if (result.isEmpty) {
      _logger.severe("Export with UUID ${uuidContainer.uuid} could not be found.");
      return new Future.value(new PadSaveObject());
    }
    _GaePadSaveObject record = result.first;
    database.commit(deletes: [record.key]).catchError((e) {
      _logger.severe("Error while deleting export ${e}");
      throw (e);
    });
    _logger.info("Deleted Export with ID ${record.uuid}");
    return new Future.value(new PadSaveObject.fromRecordSource(record));
  }

  @ApiMethod(method: 'GET', path: 'getUnusedMappingId')
  Future<UuidContainer> getUnusedMappingId() async {
    final int limit = 4;
    int attemptCount = 0;
    var database = ae.context.services.db;
    String randomUuid;
    var query;
    List result;
    do {
      randomUuid = new uuid_tools.Uuid().v4();
      query = database.query(_GistMapping)..filter('internalId =', randomUuid);
      result = await query.run().toList();
      attemptCount ++;
      if (!result.isEmpty) _logger.info("Collision in retrieving mapping id ${randomUuid}.");
    } while (!result.isEmpty && attemptCount < limit);
    if (!result.isEmpty) {
      _logger.severe("Could not generate valid ID.");
      throw new InternalServerError("Could not generate ID.");
    }
    _logger.info("Valid ID ${randomUuid} retrieved.");
    return new Future.value(new UuidContainer.fromUuid(randomUuid));
  }

  @ApiMethod(method: 'POST', path: 'storeGist')
  Future<UuidContainer> storeGist(GistToInternalIdMapping map) async {
    var database = ae.context.services.db;
    var query = database.query(_GistMapping)..filter('internalId =', map.internalId);
    List result = await query.run().toList();
    if (!result.isEmpty) {
      _logger.severe("Collision with mapping of Id ${map.gistId}.");
      throw new BadRequestError("Mapping invalid.");
    } else {
      _GistMapping entry = new _GistMapping.fromMap(map);
      db.dbService.commit(inserts: [entry]).catchError((e) {
        _logger.severe("Error while recording mapping with Id ${map.gistId}. Error ${e}");
        throw e;
      });
      _logger.info("Mapping with ID ${map.gistId} stored.");
      return new Future.value(new UuidContainer.fromUuid(map.gistId));
    }
  }

  @ApiMethod(method: 'GET', path: 'retrieveGist')
  Future<UuidContainer> retrieveGist({String id}) async {
    if (id == null) {
      throw new BadRequestError('Missing parameter: \'id\'');
    }
    var database = ae.context.services.db;
    var query = database.query(_GistMapping)..filter('internalId =', id);
    List result = await query.run().toList();
    if (result.isEmpty) {
      _logger.severe("Missing mapping for Id ${id}.");
      throw new BadRequestError("Missing mapping for Id ${id}");
    } else {
      _GistMapping entry = result.first;
      _logger.info("Mapping with ID ${id} retrieved.");
      return new Future.value(new UuidContainer.fromUuid(entry.gistId));
    }
  }
}

/**
 * Public interface object for storage of pads.
 */
class PadSaveObject {
  String dart;
  String html;
  String css;
  String uuid;
  PadSaveObject();

  PadSaveObject.fromData(String dart, String html, String css, {String uuid}) {
    this.dart = dart;
    this.html = html;
    this.css = css;
    this.uuid = uuid;
  }

  PadSaveObject.fromRecordSource(_GaePadSaveObject record) {
    this.dart = record.getDart;
    this.html = record.getHtml;
    this.css = record.getCss;
    this.uuid = record.uuid;
  }
}

/**
 * String container for IDs
 */
class UuidContainer {
  String uuid;
  UuidContainer();
  UuidContainer.fromUuid(String uuid) {
    this.uuid = uuid;
  }
}

/**
 * Map from id to id
 */
class GistToInternalIdMapping {
  String gistId;
  String internalId;
  GistToInternalIdMapping();
  GistToInternalIdMapping.fromIds(String gistId, String internalId) {
    this.gistId = gistId;
    this.internalId = internalId;
  }
}
/**
 * Internal storage representation for storage of pads.
 */
@db.Kind()
class _GaePadSaveObject extends db.Model {
  @db.BlobProperty()
  List<int> dart;

  @db.IntProperty()
  int epochTime;

  @db.BlobProperty()
  List<int> html;

  @db.BlobProperty()
  List<int> css;

  @db.StringProperty()
  String uuid;

  _GaePadSaveObject() {
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }

  _GaePadSaveObject.fromData(String dart, String html, String css,
      {String uuid}) {
    this.dart = _gzipEncode(dart);
    this.html = _gzipEncode(html);
    this.css = _gzipEncode(css);
    this.uuid = uuid;
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }

  _GaePadSaveObject.fromDSO(PadSaveObject pso) {
    this.dart = _gzipEncode(pso.dart != null ? pso.dart : "");
    this.html = _gzipEncode(pso.html != null ? pso.html : "");
    this.css = _gzipEncode(pso.css != null ? pso.css : "");
    this.uuid = pso.uuid;
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }

  String get getDart => _gzipDecode(this.dart);
  String get getHtml => _gzipDecode(this.html);
  String get getCss => _gzipDecode(this.css);
}


/**
 * Internal storage representation for gist id mapping.
 */
@db.Kind()
class _GistMapping extends db.Model {
  @db.StringProperty()
  String internalId;

  @db.StringProperty()
  String gistId;

  @db.IntProperty()
  int epochTime;

  _GistMapping() {
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }

  _GistMapping.fromMap(GistToInternalIdMapping map) {
    this.internalId = map.internalId;
    this.gistId = map.gistId;
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }
}

String _computeSHA1(_GaePadSaveObject record) {
  crypto.SHA1 sha1 = new crypto.SHA1();
  convert.Utf8Encoder utf8 = new convert.Utf8Encoder();
  sha1.add(utf8.convert(
      "blob  'n ${record.getDart} ${record.getHtml} ${record.getCss}"));
  return crypto.CryptoUtils.bytesToHex(sha1.close());
}

List<int> _gzipEncode(String input) =>
    io.GZIP.encode(convert.UTF8.encode(input));
String _gzipDecode(List<int> input) =>
    convert.UTF8.decode(io.GZIP.decode(input));
