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
import 'package:logging/logging.dart';

final Logger _logger = new Logger('dartpad_support_server');

// This class defines the interface that the server provides.
@ApiClass(name: '_dartpadsupportservices', version: 'v1')
class FileRelayServer {
  
  FileRelayServer() {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;
  }
  
  @ApiMethod(method:'POST', path:'export') 
  Future<KeyContainer> export(DataSaveObject data){
    GaeExportRecord record = new GaeExportRecord.FromDSO(data);
    sha1SetUUID(record);
    db.dbService.commit(inserts: [record])
      .catchError((e) {
      _logger.severe("Error while recording export ${e}");
      throw(e);
    });
    _logger.info("PERF: Recorded Export with ID ${record.UUID}");
    return new Future.value(new KeyContainer.FromKey(record.UUID));
  }
  
  @ApiMethod(method:'DELETE', path:'pullExportData')
  Future<DataSaveObject> pullExportContent({String key}) async {
    var database = ae.context.services.db;
    var query = database.query(GaeExportRecord)
        ..filter('UUID =', key);
    List result = await query.run().toList();
    if (result.isEmpty) {
      _logger.severe("Export with key ${key} could not be found.");
      return new Future.value(new DataSaveObject());
    }
    GaeExportRecord record = result.first;
    database.commit(deletes: [record.key]).catchError((e) {
      _logger.severe("Error while deleting export ${e}");
      throw(e);
    });
    _logger.info("PERF: Deleted Export with ID ${record.UUID}");
    return new Future.value(new DataSaveObject.FromData(record.dart, record.html, record.css));
  }
}

/*
 * This is the schema for source code storage
 */
@db.Kind()
class GaeExportRecord extends db.Model {
  @db.StringProperty()
  String dart;

  @db.StringProperty()
  String html;

  @db.StringProperty()
  String css;

  @db.StringProperty()
  String UUID;
  
  GaeExportRecord();

  GaeExportRecord.FromData(String dart, String html, String css, {String UUID}) {
    this.dart = dart;
    this.html = html;
    this.css = css;
    this.UUID = UUID;
  }
  
  GaeExportRecord.FromDSO(DataSaveObject dso) {
    this.dart = dso.dart;
    this.html = dso.html;
    this.css = dso.css;
    this.UUID = dso.UUID;
  }
}

class DataSaveObject {
  String dart;
  String html;
  String css;
  String UUID;
  DataSaveObject();

  DataSaveObject.FromData(String dart, String html, String css, {String UUID}) {
    this.dart = dart;
    this.html = html;
    this.css = css;
    this.UUID = UUID;
  }
}

class KeyContainer {
  String key;
  KeyContainer();
  KeyContainer.FromKey(String key) {
    this.key = key;
  }
}

// SHA1 set the id
void sha1SetUUID(GaeExportRecord record) {
  crypto.SHA1 sha1 = new crypto.SHA1();
  convert.Utf8Encoder utf8 = new convert.Utf8Encoder();
  sha1.add(utf8.convert('blob  \n ${record.html} ${record.css} ${record.dart}'));
  record.UUID = crypto.CryptoUtils.bytesToHex(sha1.close());
}