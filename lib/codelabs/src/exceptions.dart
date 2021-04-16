enum CodelabFetchExceptionType {
  unknown,
  contentNotFound,
  rateLimitExceeded,
  invalidMetadata,
}

class CodelabFetchException implements Exception {
  final CodelabFetchExceptionType failureType;
  final String message;

  const CodelabFetchException(this.failureType, [this.message]);
}
