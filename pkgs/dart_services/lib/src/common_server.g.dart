// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common_server.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$CommonServerApiRouter(CommonServerApi service) {
  final router = Router();
  router.add(
    'POST',
    r'/api/<apiVersion>/analyze',
    service.analyze,
  );
  router.add(
    'POST',
    r'/api/<apiVersion>/compile',
    service.compile,
  );
  router.add(
    'POST',
    r'/api/<apiVersion>/compileDDC',
    service.compileDDC,
  );
  router.add(
    'POST',
    r'/api/<apiVersion>/complete',
    service.complete,
  );
  router.add(
    'POST',
    r'/api/<apiVersion>/fixes',
    service.fixes,
  );
  router.add(
    'POST',
    r'/api/<apiVersion>/format',
    service.format,
  );
  router.add(
    'POST',
    r'/api/<apiVersion>/document',
    service.document,
  );
  router.add(
    'GET',
    r'/api/<apiVersion>/version',
    service.versionGet,
  );
  return router;
}
