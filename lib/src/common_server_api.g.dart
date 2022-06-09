// GENERATED CODE - DO NOT MODIFY BY HAND

part of services.common_server_api;

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$CommonServerApiRouter(CommonServerApi service) {
  final router = Router();
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/analyze', service.analyze);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/compile', service.compile);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/compileDDC', service.compileDDC);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/complete', service.complete);
  router.add('POST', r'/api/dartservices/<apiVersion>/fixes', service.fixes);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/assists', service.assists);
  router.add('POST', r'/api/dartservices/<apiVersion>/format', service.format);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/document', service.document);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/version', service.versionPost);
  router.add(
      'GET', r'/api/dartservices/<apiVersion>/version', service.versionGet);
  router.add('POST', r'/api/dartservices/<apiVersion>/analyzeFiles',
      service.analyzeFiles);
  router.add('POST', r'/api/dartservices/<apiVersion>/compileFiles',
      service.compileFiles);
  router.add('POST', r'/api/dartservices/<apiVersion>/compileFilesDDC',
      service.compileFilesDDC);
  router.add('POST', r'/api/dartservices/<apiVersion>/completeFiles',
      service.completeFiles);
  router.add(
      'POST', r'/api/dartservices/<apiVersion>/fixesFiles', service.fixesFiles);
  router.add('POST', r'/api/dartservices/<apiVersion>/assistsFiles',
      service.assistsFiles);
  router.add('POST', r'/api/dartservices/<apiVersion>/documentFiles',
      service.documentFiles);
  return router;
}
