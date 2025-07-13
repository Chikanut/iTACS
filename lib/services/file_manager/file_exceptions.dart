// file_exceptions.dart

class WebDownloadException implements Exception {
  final String message;
  final String fileId;
  final String? url;

  WebDownloadException(this.message, this.fileId, [this.url]);

  @override
  String toString() =>
      'WebDownloadException: $message${url != null ? ' (URL: $url)' : ''}';
}

class MetadataException implements Exception {
  final String message;
  final String? fileId;

  MetadataException(this.message, [this.fileId]);

  @override
  String toString() =>
      'MetadataException: $message${fileId != null ? ' (fileId: $fileId)' : ''}';
}

class FileMetadataException implements Exception {
  final String message;
  final String fileId;

  FileMetadataException(this.message, this.fileId);

  @override
  String toString() => 'FileMetadataException: $message (fileId: $fileId)';
}

class FileAccessException implements Exception {
  final String message;
  final String fileId;

  FileAccessException(this.message, this.fileId);

  @override
  String toString() => 'FileAccessException: $message (fileId: $fileId)';
}

