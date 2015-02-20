library dartservices_clientlib.common;

import 'dart:async' as async;
import 'dart:core' as core;

/**
 * Represents a media consisting of a stream of bytes, a content type and a
 * length.
 */
class Media {
  final async.Stream<core.List<core.int>> stream;
  final core.String contentType;
  final core.int length;

  /**
   * Creates a new [Media] with a byte [stream] of length [length] with a
   * [contentType].
   *
   * When uploading media, [length] can only be null if [ResumableUploadOptions]
   * is used.
   */
  Media(this.stream, this.length,
        {this.contentType: "application/octet-stream"}) {
    if (stream == null || contentType == null) {
      throw new core.ArgumentError(
          'Arguments stream, contentType and length must not be null.');
    }
    if (length != null && length < 0) {
      throw new core.ArgumentError('A negative content length is not allowed');
    }
  }
}

/**
 * Represents options for uploading a [Media].
 */
class UploadOptions {
  /** Use either simple uploads (only media) or multipart for media+metadata */
  static const UploadOptions Default = const UploadOptions();

  /** Make resumable uploads */
  static final ResumableUploadOptions Resumable = new ResumableUploadOptions();

  const UploadOptions();
}

/**
 * Specifies options for resumable uploads.
 */
class ResumableUploadOptions extends UploadOptions {
  static final core.Function ExponentialBackoff = (core.int failedAttempts) {
    // Do not retry more than 5 times.
    if (failedAttempts > 5) return null;

    // Wait for 2^(failedAttempts-1) seconds, before retrying.
    // i.e. 1 second, 2 seconds, 4 seconds, ...
    return new core.Duration(seconds: 1 << (failedAttempts - 1));
  };

  /**
   * Maximum number of upload attempts per chunk.
   */
  final core.int numberOfAttempts;

  /**
   * Preferred size (in bytes) of a uploaded chunk.
   * Must be a multiple of 256 KB.
   *
   * The default is 1 MB.
   */
  final core.int chunkSize;

  /**
   * Function for determining the [core.Duration] to wait before making the
   * next attempt. See [ExponentialBackoff] for an example.
   */
  final core.Function backoffFunction;

  ResumableUploadOptions({this.numberOfAttempts: 3,
                          this.chunkSize: 1024 * 1024,
                          core.Function backoffFunction})
      : backoffFunction = backoffFunction == null ?
          ExponentialBackoff : backoffFunction {
    // See e.g. here:
    // https://developers.google.com/maps-engine/documentation/resumable-upload
    //
    // Chunk size restriction:
    // There are some chunk size restrictions based on the size of the file you
    // are uploading. Files larger than 256 KB (256 x 1024 bytes) must have
    // chunk sizes that are multiples of 256 KB. For files smaller than 256 KB,
    // there are no restrictions. In either case, the final chunk has no
    // limitations; you can simply transfer the remaining bytes. If you use
    // chunking, it is important to keep the chunk size as large as possible
    // to keep the upload efficient.
    //
    if (numberOfAttempts < 1 || (chunkSize % (256 * 1024)) != 0) {
      throw new core.ArgumentError('Invalid arguments.');
    }
  }
}

/**
 * Represents options for downloading media.
 *
 * For partial downloads, see [PartialDownloadOptions].
 */
class DownloadOptions {
  /** Download only metadata. */
  static const DownloadOptions Metadata = const DownloadOptions();

  /** Download full media. */
  static final PartialDownloadOptions FullMedia =
      new PartialDownloadOptions(new ByteRange(0, -1));

  const DownloadOptions();

  /** Indicates whether metadata should be downloaded. */
  core.bool get isMetadataDownload => true;
}

/**
 * Options for downloading a [Media].
 */
class PartialDownloadOptions extends DownloadOptions {
  /** The range of bytes to be downloaded */
  final ByteRange range;

  PartialDownloadOptions(this.range);

  core.bool get isMetadataDownload => false;

  /**
   * `true` if this is a full download and `false` if this is a partial
   * download.
   */
  core.bool get isFullDownload => range.start == 0 && range.end == -1;
}

/**
 * Specifies a range of media.
 */
class ByteRange {
  /** First byte of media. */
  final core.int start;

  /** Last byte of media (inclusive) */
  final core.int end;

  /** Length of this range (i.e. number of bytes) */
  core.int get length => end - start + 1;

  ByteRange(this.start, this.end) {
    if (!(start == 0  && end == -1 || start >= 0 && end > start)) {
      throw new core.ArgumentError('Invalid media range [$start, $end]');
    }
  }
}

/**
 * Represents a general error reported by the API endpoint.
 */
class ApiRequestError extends core.Error {
  final core.String message;

  ApiRequestError(this.message);

  core.String toString() => 'ApiRequestError(message: $message)';
}

/**
 * Represents a specific error reported by the API endpoint.
 */
class DetailedApiRequestError extends ApiRequestError {
  final core.int status;

  DetailedApiRequestError(this.status, core.String message) : super(message);

  core.String toString()
      => 'DetailedApiRequestError(status: $status, message: $message)';
}
