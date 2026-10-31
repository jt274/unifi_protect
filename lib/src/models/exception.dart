/// Exception thrown when a UniFi Protect HTTP request fails.
class ProtectHttpException implements Exception {
  /// Creates a [ProtectHttpException] with [message], optional [statusCode], and [uri].
  const ProtectHttpException(
    this.message, {
    this.statusCode,
    this.uri,
  });

  /// Human-readable error message describing the failure.
  final String message;

  /// HTTP status code returned by the server, if available.
  final int? statusCode;

  /// URI of the request that failed.
  final Uri? uri;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('ProtectHttpException: $message');
    if (statusCode != null) {
      buffer.write(' (HTTP $statusCode)');
    }
    if (uri != null) {
      buffer.write(', uri: $uri');
    }
    return buffer.toString();
  }
}
