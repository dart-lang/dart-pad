// @dart=2.9

enum WorkshopFetchExceptionType {
  unknown,
  contentNotFound,
  rateLimitExceeded,
  invalidMetadata,
}

class WorkshopFetchException implements Exception {
  final WorkshopFetchExceptionType failureType;
  final String message;

  const WorkshopFetchException(this.failureType, [this.message]);
}
