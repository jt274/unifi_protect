/// Utility for sanitizing and converting UniFi Protect RTSP and RTSPS URLs.
///
/// UniFi Protect provides RTSPS URLs in the format:
///   `rtsps://192.168.1.1:7441/AbCdEfGhIjKlMnOp?enableSrtp`
/// Standard unencrypted local RTSP streams are served on port `7447` without `?enableSrtp`:
///   `rtsp://192.168.1.1:7447/AbCdEfGhIjKlMnOp`
class RtspSanitizer {
  const RtspSanitizer._();

  /// Singleton instance of [RtspSanitizer].
  static const RtspSanitizer instance = RtspSanitizer._();

  /// Converts a UniFi `rtsps://...:7441/...?enableSrtp` URL to `rtsp://...:7447/...`
  /// while preserving credentials, host, path, and any non-SRTP query parameters.
  static String sanitize(String rawUrl) {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      return trimmed;
    }

    final String schemeLower = parsed.scheme.toLowerCase();
    if (schemeLower != 'rtsps' && schemeLower != 'rtsp') {
      return trimmed;
    }

    final bool isUnifiRtsps = schemeLower == 'rtsps' ||
        parsed.port == 7441 ||
        parsed.queryParameters.containsKey('enableSrtp');

    if (!isUnifiRtsps) {
      return trimmed;
    }

    final int targetPort =
        (parsed.port == 7441 || parsed.port == 0) ? 7447 : parsed.port;

    final Map<String, String> filteredQueryParams = Map<String, String>.from(
      parsed.queryParameters,
    )..removeWhere((String key, _) => key.toLowerCase() == 'enablesrtp');

    final Uri sanitizedUri = Uri(
      scheme: 'rtsp',
      userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
      host: parsed.host,
      port: targetPort,
      path: parsed.path,
      queryParameters: filteredQueryParams.isEmpty ? null : filteredQueryParams,
    );

    return sanitizedUri.toString();
  }

  /// Cleans any RTSP/RTSPS stream URL by stripping `?enableSrtp` which breaks
  /// standard FFmpeg / libmpv TLS negotiation.
  static String cleanStreamUrl(String rawUrl) {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.queryParameters.containsKey('enableSrtp')) {
      return trimmed;
    }

    final Map<String, String> filteredParams =
        Map<String, String>.from(parsed.queryParameters)
          ..removeWhere((String key, _) => key.toLowerCase() == 'enablesrtp');

    return Uri(
      scheme: parsed.scheme,
      userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
      host: parsed.host,
      port: parsed.port != 0 ? parsed.port : null,
      path: parsed.path,
      queryParameters: filteredParams.isEmpty ? null : filteredParams,
    ).toString();
  }

  /// Converts an unencrypted RTSP URL (`rtsp://...:7447/...`) to an encrypted
  /// RTSPS URL (`rtsps://...:7441/...`) without `?enableSrtp`.
  static String toRtsps(String rawUrl) {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      return trimmed;
    }

    final int targetPort =
        (parsed.port == 7447 || parsed.port == 0) ? 7441 : parsed.port;
    final Map<String, String> queryParams =
        Map<String, String>.from(parsed.queryParameters)
          ..removeWhere((String key, _) => key.toLowerCase() == 'enablesrtp');

    final Uri rtspsUri = Uri(
      scheme: 'rtsps',
      userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
      host: parsed.host,
      port: targetPort,
      path: parsed.path,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    return rtspsUri.toString();
  }

  /// Converts an RTSP/RTSPS URL to `rtsps://<host>:7441/<token>?enableSrtp`.
  static String toRtspsWithSrtp(String rawUrl) {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      return trimmed;
    }

    final int targetPort =
        (parsed.port == 7447 || parsed.port == 0) ? 7441 : parsed.port;
    final Map<String, String> queryParams =
        Map<String, String>.from(parsed.queryParameters)
          ..removeWhere((String key, _) => key.toLowerCase() == 'enablesrtp');

    final String baseUri = Uri(
      scheme: 'rtsps',
      userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
      host: parsed.host,
      port: targetPort,
      path: parsed.path,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    ).toString();

    return baseUri.contains('?')
        ? '$baseUri&enableSrtp'
        : '$baseUri?enableSrtp';
  }

  /// Returns `true` if the path segment of [url] is a 24-hex-character UniFi
  /// Protect camera ID (MongoDB ObjectId) or matches [cameraId], indicating
  /// that the URL uses the camera ID placeholder rather than a 16-character
  /// RTSP stream token.
  static bool isCameraIdPlaceholderUrl(String url, {String? cameraId}) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.pathSegments.isEmpty) {
      return false;
    }

    final String lastSegment = parsed.pathSegments.last.trim();
    if (lastSegment.isEmpty) {
      return false;
    }

    if (cameraId != null &&
        cameraId.trim().isNotEmpty &&
        lastSegment.toLowerCase() == cameraId.trim().toLowerCase()) {
      return true;
    }

    // UniFi Protect camera IDs are 24-character hex strings (e.g. 68d5cf8800b0a003e401a7ec),
    // whereas RTSP stream tokens are 16-character mixed-case alphanumeric strings.
    final RegExp hexObjectIdPattern = RegExp(r'^[0-9a-fA-F]{24}$');
    return hexObjectIdPattern.hasMatch(lastSegment);
  }

  /// Returns an ordered list of unique candidate stream URLs to try for a UniFi
  /// Protect stream token (`rtsp://:7447/<token>`, `rtsps://:7441/<token>?enableSrtp`,
  /// and `rtsps://:7441/<token>`).
  static List<String> getCandidateUrls(String rawUrl) {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      return <String>[trimmed];
    }

    final String scheme = parsed.scheme.toLowerCase();
    final bool isUnifiPort = parsed.port == 7447 ||
        parsed.port == 7441 ||
        scheme == 'rtsps' ||
        parsed.queryParameters.containsKey('enableSrtp');

    if (!isUnifiPort) {
      return <String>[trimmed];
    }

    final List<String> candidates = <String>[];
    void addUnique(String candidate) {
      if (candidate.isNotEmpty && !candidates.contains(candidate)) {
        candidates.add(candidate);
      }
    }

    final String rtsp7447 = sanitize(trimmed);
    final String rtsps7441NoSrtp = toRtsps(trimmed);
    final String rtsps7441WithSrtp = toRtspsWithSrtp(trimmed);

    if (scheme == 'rtsps' || parsed.port == 7441) {
      addUnique(rtsps7441NoSrtp);
      addUnique(rtsp7447);
      addUnique(rtsps7441WithSrtp);
    } else {
      addUnique(rtsp7447);
      addUnique(rtsps7441NoSrtp);
      addUnique(rtsps7441WithSrtp);
    }

    return candidates;
  }

  /// Returns the alternate RTSP/RTSPS URI for UniFi Protect streams
  /// (swapping port 7447 <-> 7441 and scheme rtsp <-> rtsps) to allow
  /// automatic fallback if one port is unreachable.
  static String? getAlternateUrl(String url) {
    final String cleaned = cleanStreamUrl(url);
    final Uri? parsed = Uri.tryParse(cleaned);
    if (parsed == null || parsed.host.isEmpty) {
      return null;
    }

    final String scheme = parsed.scheme.toLowerCase();
    if (scheme == 'rtsps' || parsed.port == 7441) {
      final String sanitized = sanitize(cleaned);
      return sanitized != cleaned ? sanitized : null;
    } else if (scheme == 'rtsp' && parsed.port == 7447) {
      final String rtsps = toRtsps(cleaned);
      return rtsps != cleaned ? rtsps : null;
    }
    return null;
  }
}
