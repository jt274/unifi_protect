import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/camera.dart';
import '../models/channel.dart';
import '../models/exception.dart';
import '../models/stream_quality.dart';
import '../utils/rtsp_sanitizer.dart';

/// Service for managing UniFi Protect cameras, video streams, snapshots, and PTZ controls.
class CameraService {
  /// Creates a [CameraService] with the given [options] and HTTP [client].
  CameraService({
    required this.options,
    required this.client,
  });

  /// The active UniFi Protect client connection options.
  final UnifiProtectOptions options;

  /// The HTTP client used to perform API requests.
  final http.Client client;

  /// Retrieves all adopted cameras and doorbells.
  Future<List<ProtectCamera>> listCameras() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for listCameras',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final List<dynamic> list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List<dynamic>
            : <dynamic>[]);

    return list
        .whereType<Map<String, dynamic>>()
        .map(ProtectCamera.fromJson)
        .toList();
  }

  /// Retrieves details for a specific camera by [id].
  Future<ProtectCamera> getCamera(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getCamera ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object for camera details');
    }

    return ProtectCamera.fromJson(decoded);
  }

  /// Partially updates camera configuration settings (e.g. name, OSD settings).
  Future<ProtectCamera> updateCamera(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id',
    );

    final http.Response response = await client
        .patch(
          uri,
          headers: <String, String>{
            ...options.headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(patch),
        )
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for updateCamera ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getCamera(id);
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectCamera.fromJson(decoded as Map<String, dynamic>);
  }

  /// Captures a still JPEG snapshot image from [id].
  ///
  /// [channel] can be `'main'` or `'package'` (for Doorbell Pro).
  /// [highQuality] forces a 1080p or higher resolution snapshot.
  Future<Uint8List> getSnapshot(
    String id, {
    String channel = 'main',
    bool highQuality = false,
  }) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/snapshot',
      queryParameters: <String, String>{
        if (channel != 'main') 'channel': channel,
        if (highQuality) 'highQuality': 'true',
      },
    );

    final http.Response response = await client.get(
      uri,
      headers: <String, String>{
        'X-API-KEY': options.apiKey.trim(),
        'Accept': 'image/jpeg',
      },
    ).timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'Failed to capture snapshot from camera $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    return response.bodyBytes;
  }

  /// Gets currently active RTSPS streams for [id].
  /// Returns a map of quality names to stream URLs:
  /// e.g. `{'low': 'rtsp://...:7447/tokenLow', 'high': 'rtsp://...:7447/tokenHigh'}`.
  Future<Map<String, String>> getRtspsStreams(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/rtsps-stream',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      return const <String, String>{};
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <String, String>{};
    }

    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, dynamic> entry in decoded.entries) {
      final String val = entry.value?.toString().trim() ?? '';
      if (val.isNotEmpty) {
        final Uri? parsed = Uri.tryParse(val);
        if (parsed != null && parsed.pathSegments.isNotEmpty) {
          final String rewritten = Uri(
            scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'rtsps',
            userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
            host: options.cleanHost,
            port: parsed.port != 0 ? parsed.port : 7441,
            path: parsed.path,
            queryParameters:
                parsed.queryParameters.isEmpty ? null : parsed.queryParameters,
          ).toString();
          result[entry.key.toLowerCase()] = RtspSanitizer.sanitize(rewritten);
        }
      }
    }
    return result;
  }

  /// Generates or enables an RTSPS stream for [id] with the requested [qualities].
  Future<Map<String, String>> createRtspsStream(
    String id, {
    List<String> qualities = const <String>['low'],
  }) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/rtsps-stream',
    );

    final http.Response response = await client
        .post(
          uri,
          headers: <String, String>{
            ...options.headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'qualities': qualities,
          }),
        )
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ProtectHttpException(
        'Failed to create RTSPS stream for $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <String, String>{};
    }

    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, dynamic> entry in decoded.entries) {
      final String val = entry.value?.toString().trim() ?? '';
      if (val.isNotEmpty) {
        final Uri? parsed = Uri.tryParse(val);
        if (parsed != null && parsed.pathSegments.isNotEmpty) {
          final String rewritten = Uri(
            scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'rtsps',
            userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
            host: options.cleanHost,
            port: parsed.port != 0 ? parsed.port : 7441,
            path: parsed.path,
            queryParameters:
                parsed.queryParameters.isEmpty ? null : parsed.queryParameters,
          ).toString();
          result[entry.key.toLowerCase()] = RtspSanitizer.sanitize(rewritten);
        }
      }
    }
    return result;
  }

  /// Deletes or disables the active RTSPS streams for [id].
  Future<void> deleteRtspsStream(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/rtsps-stream',
    );

    final http.Response response = await client
        .delete(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw ProtectHttpException(
        'Failed to delete RTSPS stream for $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }

  /// Moves a Pan-Tilt-Zoom (PTZ) camera to the designated preset [slot].
  /// `slot = -1` returns the camera to its Home position.
  Future<void> moveToPtzPreset(String id, int slot) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/ptz/goto/$slot',
    );

    final http.Response response = await client
        .post(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ProtectHttpException(
        'Failed to move PTZ camera $id to slot $slot (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }

  /// Starts an automated PTZ patrol on [slot].
  Future<void> startPtzPatrol(String id, int slot) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/ptz/patrol/start/$slot',
    );

    final http.Response response = await client
        .post(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ProtectHttpException(
        'Failed to start PTZ patrol on camera $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }

  /// Stops an active PTZ patrol on [id].
  Future<void> stopPtzPatrol(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/ptz/patrol/stop',
    );

    final http.Response response = await client
        .post(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ProtectHttpException(
        'Failed to stop PTZ patrol on camera $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }

  /// Disables the camera microphone.
  Future<void> disableMicrophone(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/microphone/disable',
    );

    final http.Response response = await client
        .post(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ProtectHttpException(
        'Failed to disable microphone on camera $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }

  /// Initializes a 2-way talkback audio session on [id].
  Future<Map<String, dynamic>> createTalkbackSession(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/cameras/$id/talkback-session',
    );

    final http.Response response = await client
        .post(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ProtectHttpException(
        'Failed to start talkback session for camera $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
  }

  /// Scans both NVR channels and active RTSPS endpoints to fetch all available stream quality URLs for [id].
  Future<Map<String, String>> fetchAvailableStreamQualities(String id) async {
    final Map<String, String> result = <String, String>{};

    try {
      final ProtectCamera camera = await getCamera(id);
      for (final CameraChannel ch in camera.channels) {
        if (ch.isRtspEnabled &&
            ch.rtspAlias != null &&
            ch.rtspAlias!.isNotEmpty) {
          final String rawUrl =
              'rtsp://${options.cleanHost}:7447/${ch.rtspAlias}';
          final String sanitized = RtspSanitizer.sanitize(rawUrl);
          if (ch.matchesQuality(StreamQuality.low)) {
            result['low'] = sanitized;
          } else if (ch.matchesQuality(StreamQuality.medium)) {
            result['medium'] = sanitized;
          } else if (ch.matchesQuality(StreamQuality.high)) {
            result['high'] = sanitized;
          } else if (ch.matchesQuality(StreamQuality.package)) {
            result['package'] = sanitized;
          }
        }
      }
    } catch (_) {}

    try {
      final Map<String, String> rtsps = await getRtspsStreams(id);
      for (final MapEntry<String, String> entry in rtsps.entries) {
        result.putIfAbsent(entry.key.toLowerCase(), () => entry.value);
      }
    } catch (_) {}

    return result;
  }

  /// Extracts the stream URL from a UniFi Protect `/rtsps-stream` JSON response,
  /// respecting the specified [qualityPreference] or [isPackageCamera], rewrites
  /// the host to [nvrHost], and sanitizes it.
  /// When [exactMatchOnly] is true, only searches for the requested quality.
  static String? extractStreamUrlFromResponse(
    String responseBody, {
    required String nvrHost,
    StreamQuality qualityPreference = StreamQuality.low,
    bool isPackageCamera = false,
    bool exactMatchOnly = false,
  }) {
    if (responseBody.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final List<String> searchKeys;
      if (isPackageCamera) {
        searchKeys = exactMatchOnly
            ? const <String>['package']
            : const <String>['package', 'low', 'medium', 'high'];
      } else if (exactMatchOnly) {
        searchKeys = <String>[qualityPreference.name.toLowerCase()];
      } else {
        switch (qualityPreference) {
          case StreamQuality.low:
            searchKeys = const <String>['low', 'medium', 'high'];
          case StreamQuality.medium:
            searchKeys = const <String>['medium', 'high', 'low'];
          case StreamQuality.high:
          case StreamQuality.package:
            searchKeys = const <String>['high', 'medium', 'low'];
        }
      }

      for (final String key in searchKeys) {
        final dynamic rawVal = decoded[key];
        if (rawVal is String && rawVal.trim().isNotEmpty) {
          final Uri? parsed = Uri.tryParse(rawVal.trim());
          if (parsed != null && parsed.pathSegments.isNotEmpty) {
            final String rewritten = Uri(
              scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'rtsps',
              userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
              host: nvrHost,
              port: parsed.port != 0 ? parsed.port : 7441,
              path: parsed.path,
              queryParameters: parsed.queryParameters.isEmpty
                  ? null
                  : parsed.queryParameters,
            ).toString();
            return RtspSanitizer.sanitize(rewritten);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches an existing RTSP/RTSPS stream URL or creates one on-demand.
  Future<String?> fetchOrCreateStreamUrl(
    String id, {
    StreamQuality quality = StreamQuality.low,
    bool exactMatchOnly = false,
  }) async {
    final bool isPackageCamera = id.endsWith('_package');
    final String actualId =
        isPackageCamera ? id.substring(0, id.length - '_package'.length) : id;

    // 1. Check existing streams
    final Map<String, String> activeStreams = await getRtspsStreams(actualId);
    final String targetKey =
        isPackageCamera ? 'package' : quality.name.toLowerCase();
    if (activeStreams.containsKey(targetKey)) {
      return activeStreams[targetKey];
    }

    if (!exactMatchOnly && !isPackageCamera) {
      final List<String> searchOrder = quality == StreamQuality.low
          ? const <String>['low', 'medium', 'high']
          : const <String>['high', 'medium', 'low'];
      for (final String k in searchOrder) {
        if (activeStreams.containsKey(k)) {
          return activeStreams[k];
        }
      }
    }

    // 2. Request creation if not found
    final List<String> qualitiesToRequest = isPackageCamera
        ? const <String>['package']
        : (exactMatchOnly
            ? <String>[quality.name.toLowerCase()]
            : (quality == StreamQuality.low
                ? const <String>['low', 'medium', 'high']
                : const <String>['high', 'medium', 'low']));

    for (final String q in qualitiesToRequest) {
      try {
        final Map<String, String> created =
            await createRtspsStream(actualId, qualities: <String>[q]);
        if (created.containsKey(q)) {
          return created[q];
        }
      } catch (_) {}
    }

    return null;
  }
}
