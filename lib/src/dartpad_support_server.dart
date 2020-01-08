// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.database;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'dart:mirrors' as mirrors;

import 'package:appengine/appengine.dart' as ae;
import 'package:crypto/crypto.dart' as crypto;
import 'package:gcloud/db.dart' as db;
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rpc/rpc.dart';
import 'package:uuid/uuid.dart' as uuid_tools;

final Logger _logger = Logger('dartpad_support_server');

// This class defines the interface that the server provides.
@ApiClass(name: '_dartpadsupportservices', version: 'v1')
class FileRelayServer {
  Map<String, List<dynamic>> database;
  bool test;

  String getTypeName(dynamic obj) =>
      mirrors.reflect(obj).type.reflectedType.toString();

  String getClass(dynamic obj) => mirrors.MirrorSystem.getName(
      mirrors.reflectClass(obj as Type).simpleName);

  FileRelayServer({this.test = false}) {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;
    if (test) {
      database = <String, List<dynamic>>{};
    }
  }

  Future<List<dynamic>> _databaseQuery<T extends db.Model>(
      String attribute, dynamic value) async {
    var result = <dynamic>[];
    if (test) {
      final dataList = database[getClass(T)];
      if (dataList != null) {
        for (final dataObject in dataList) {
          final dataObjectMirror = mirrors.reflect(dataObject);
          final futureValue =
              dataObjectMirror.getField(Symbol(attribute.split(' ')[0]));
          if (futureValue.hasReflectee && futureValue.reflectee == value) {
            result.add(dataObject);
          }
        }
      }
    } else {
      final query = ae.context.services.db.query<T>()..filter(attribute, value);
      result = await query.run().toList();
    }
    return Future<List<dynamic>>.value(result);
  }

  Future<void> _databaseCommit({List<db.Model> inserts, List<db.Key> deletes}) {
    if (test) {
      if (inserts != null) {
        for (final insertObject in inserts) {
          if (!database.containsKey(getTypeName(insertObject))) {
            database[getTypeName(insertObject)] = <dynamic>[];
          }
          database[getTypeName(insertObject)].add(insertObject);
        }
      }
      if (deletes != null) {
        // TODO: Implement delete
      }
    } else {
      ae.context.services.db.commit(inserts: inserts, deletes: deletes);
    }
    return Future<void>.value(null);
  }

  @ApiMethod(
      method: 'POST',
      path: 'export',
      description: 'Store a gist dataset to be retrieved.')
  Future<UuidContainer> export(PadSaveObject data) {
    final record = _GaePadSaveObject.fromDSO(data);
    final randomUuid = uuid_tools.Uuid().v4();
    record.uuid = '${_computeSHA1(record)}-$randomUuid';
    _databaseCommit(inserts: <db.Model>[record]).catchError((dynamic e) {
      _logger.severe('Error while recording export $e');
      throw e;
    });
    _logger.info('Recorded Export with ID ${record.uuid}');
    return Future<UuidContainer>.value(UuidContainer.fromUuid(record.uuid));
  }

  @ApiMethod(
      method: 'POST',
      path: 'pullExportData',
      description: 'Retrieve a stored gist data set.')
  Future<PadSaveObject> pullExportContent(UuidContainer uuidContainer) async {
    final result =
        await _databaseQuery<_GaePadSaveObject>('uuid =', uuidContainer.uuid);
    if (result.isEmpty) {
      _logger
          .severe('Export with UUID ${uuidContainer.uuid} could not be found.');
      throw BadRequestError('Nothing of correct uuid could be found.');
    }
    final record = result.first as _GaePadSaveObject;
    if (!test) {
      unawaited(_databaseCommit(deletes: <db.Key>[record.key])
          .catchError((dynamic e) {
        _logger.severe('Error while deleting export $e');
        throw (e);
      }));
      _logger.info('Deleted Export with ID ${record.uuid}');
    }
    return Future<PadSaveObject>.value(PadSaveObject.fromRecordSource(record));
  }

  @ApiMethod(method: 'GET', path: 'getUnusedMappingId')
  Future<UuidContainer> getUnusedMappingId() async {
    final limit = 4;
    var attemptCount = 0;
    String randomUuid;
    List<dynamic> result;
    do {
      randomUuid = uuid_tools.Uuid().v4();
      result = await _databaseQuery<_GistMapping>('internalId =', randomUuid);
      attemptCount++;
      if (result.isNotEmpty) {
        _logger.info('Collision in retrieving mapping id $randomUuid.');
      }
    } while (result.isNotEmpty && attemptCount < limit);
    if (result.isNotEmpty) {
      _logger.severe('Could not generate valid ID.');
      throw InternalServerError('Could not generate ID.');
    }
    _logger.info('Valid ID $randomUuid retrieved.');
    return Future<UuidContainer>.value(UuidContainer.fromUuid(randomUuid));
  }

  @ApiMethod(method: 'POST', path: 'storeGist')
  Future<UuidContainer> storeGist(GistToInternalIdMapping map) async {
    final result =
        await _databaseQuery<_GistMapping>('internalId =', map.internalId);
    if (result.isNotEmpty) {
      _logger.severe('Collision with mapping of Id ${map.gistId}.');
      throw BadRequestError('Mapping invalid.');
    } else {
      final entry = _GistMapping.fromMap(map);
      unawaited(
          _databaseCommit(inserts: <db.Model>[entry]).catchError((dynamic e) {
        _logger.severe(
            'Error while recording mapping with Id ${map.gistId}. Error $e');
        throw e;
      }));
      _logger.info('Mapping with ID ${map.gistId} stored.');
      return Future<UuidContainer>.value(UuidContainer.fromUuid(map.gistId));
    }
  }

  @ApiMethod(method: 'GET', path: 'retrieveGist')
  Future<UuidContainer> retrieveGist({String id}) async {
    if (id == null) {
      throw BadRequestError('Missing parameter: \'id\'');
    }
    final result = await _databaseQuery<_GistMapping>('internalId =', id);
    if (result.isEmpty) {
      _logger.severe('Missing mapping for Id $id.');
      throw BadRequestError('Missing mapping for Id $id');
    } else {
      final entry = result.first as _GistMapping;
      _logger.info('Mapping with ID $id retrieved.');
      return Future<UuidContainer>.value(UuidContainer.fromUuid(entry.gistId));
    }
  }
}

/// Public interface object for storage of pads.
class PadSaveObject {
  String dart;
  String html;
  String css;
  String uuid;

  PadSaveObject();

  PadSaveObject.fromData(this.dart, this.html, this.css, {this.uuid});

  PadSaveObject.fromRecordSource(_GaePadSaveObject record) {
    dart = record.getDart;
    html = record.getHtml;
    css = record.getCss;
    uuid = record.uuid;
  }
}

/// String container for IDs
class UuidContainer {
  String uuid;

  UuidContainer();

  UuidContainer.fromUuid(this.uuid);
}

/// Map from id to id
class GistToInternalIdMapping {
  String gistId;
  String internalId;

  GistToInternalIdMapping();

  GistToInternalIdMapping.fromIds(this.gistId, this.internalId);
}

/// Internal storage representation for storage of pads.
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
    epochTime = DateTime.now().millisecondsSinceEpoch;
  }

  _GaePadSaveObject.fromData(String dart, String html, String css,
      {this.uuid}) {
    this.dart = _gzipEncode(dart);
    this.html = _gzipEncode(html);
    this.css = _gzipEncode(css);
    epochTime = DateTime.now().millisecondsSinceEpoch;
  }

  _GaePadSaveObject.fromDSO(PadSaveObject pso) {
    dart = _gzipEncode(pso.dart ?? '');
    html = _gzipEncode(pso.html ?? '');
    css = _gzipEncode(pso.css ?? '');
    uuid = pso.uuid;
    epochTime = DateTime.now().millisecondsSinceEpoch;
  }

  String get getDart => _gzipDecode(dart);

  String get getHtml => _gzipDecode(html);

  String get getCss => _gzipDecode(css);
}

/// Internal storage representation for gist id mapping.
@db.Kind()
class _GistMapping extends db.Model {
  @db.StringProperty()
  String internalId;

  @db.StringProperty()
  String gistId;

  @db.IntProperty()
  int epochTime;

  _GistMapping() {
    epochTime = DateTime.now().millisecondsSinceEpoch;
  }

  _GistMapping.fromMap(GistToInternalIdMapping map) {
    internalId = map.internalId;
    gistId = map.gistId;
    epochTime = DateTime.now().millisecondsSinceEpoch;
  }
}

String _computeSHA1(_GaePadSaveObject record) {
  final utf8 = convert.Utf8Encoder();
  return crypto.sha1
      .convert(utf8.convert(
          "blob  'n ${record.getDart} ${record.getHtml} ${record.getCss}"))
      .toString();
}

List<int> _gzipEncode(String input) =>
    io.gzip.encode(convert.utf8.encode(input));

String _gzipDecode(List<int> input) =>
    convert.utf8.decode(io.gzip.decode(input));
