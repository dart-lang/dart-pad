// GENERATED CODE - DO NOT MODIFY BY HAND

part of services.common_server_proto;

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$CommonServerProtoRouter(CommonServerProto service) {
  final router = Router();
  router.add('POST', r'/api/dartservices/v2/analyze', service.analyze);
  router.add('POST', r'/api/dartservices/v2/compile', service.compile);
  router.add('POST', r'/api/dartservices/v2/compileDDC', service.compileDDC);
  router.add('POST', r'/api/dartservices/v2/complete', service.complete);
  router.add('POST', r'/api/dartservices/v2/fixes', service.fixes);
  router.add('POST', r'/api/dartservices/v2/assists', service.assists);
  router.add('POST', r'/api/dartservices/v2/format', service.format);
  router.add('POST', r'/api/dartservices/v2/document', service.document);
  router.add('POST', r'/api/dartservices/v2/version', service.versionPost);
  router.add('GET', r'/api/dartservices/v2/version', service.versionGet);
  return router;
}
