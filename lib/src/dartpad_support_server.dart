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

final Logger _logger = new Logger('dartpad_support_server');

// This class defines the interface that the server provides.
@ApiClass(name: '_dartpadsupportservices', version: 'v1')
class FileRelayServer {
  FileRelayServer() {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;
  }

  @ApiMethod(method: 'POST', path: 'export')
  Future<UuidContainer> export(PadSaveObject data) {
    _GaePadSaveObject record = new _GaePadSaveObject.FromDSO(data);
    record.uuid = _computeSHA1(record);
    db.dbService.commit(inserts: [record]).catchError((e) {
      _logger.severe("Error while recording export ${e}");
      throw e;
    });
    _logger.info("Recorded Export with ID ${record.uuid}");
    return new Future.value(new UuidContainer.FromUuid(record.uuid));
  }

  @ApiMethod(method: 'DELETE', path: 'pullExportData')
  Future<PadSaveObject> pullExportContent({String uuid}) async {
    var database = ae.context.services.db;
    var query = database.query(_GaePadSaveObject)..filter('UUID =', uuid);
    List result = await query.run().toList();
    if (result.isEmpty) {
      _logger.severe("Export with UUID ${uuid} could not be found.");
      return new Future.value(new PadSaveObject());
    }
    _GaePadSaveObject record = result.first;
    database.commit(deletes: [record.key]).catchError((e) {
      _logger.severe("Error while deleting export ${e}");
      throw (e);
    });
    _logger.info("Deleted Export with ID ${record.uuid}");
    return new Future.value(new PadSaveObject.FromRecordSource(record));
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

  PadSaveObject.FromData(String dart, String html, String css, {String uuid}) {
    this.dart = dart;
    this.html = html;
    this.css = css;
    this.uuid = uuid;
  }

  PadSaveObject.FromRecordSource(_GaePadSaveObject record) {
    this.dart = record.getDart;
    this.html = record.getHtml;
    this.css = record.getCss;
    this.uuid = record.uuid;
  }
}

class UuidContainer {
  String uuid;
  UuidContainer.FromUuid(String uuid) {
    this.uuid = uuid;
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

  _GaePadSaveObject.FromData(String dart, String html, String css,
      {String uuid}) {
    this.dart = _gzipEncode(dart);
    this.html = _gzipEncode(html);
    this.css = _gzipEncode(css);
    ;
    this.uuid = uuid;
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }

  _GaePadSaveObject.FromDSO(PadSaveObject pso) {
    this.dart = _gzipEncode(pso.dart);
    this.html = _gzipEncode(pso.html);
    this.css = _gzipEncode(pso.css);
    this.uuid = pso.uuid;
    this.epochTime = new DateTime.now().millisecondsSinceEpoch;
  }

  String get getDart => _gzipDecode(this.dart);
  String get getHtml => _gzipDecode(this.html);
  String get getCss => _gzipDecode(this.css);
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
