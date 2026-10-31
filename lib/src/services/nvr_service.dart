import 'dart:convert';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/exception.dart';
import '../models/meta_info.dart';
import '../models/nvr.dart';

/// Service for retrieving UniFi Protect application metadata and NVR system details.
class NvrService {
  NvrService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Retrieves Protect application metadata, versions, and build info.
  Future<ProtectMetaInfo> getMetaInfo() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/meta/info',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getMetaInfo',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectMetaInfo.fromJson(decoded as Map<String, dynamic>);
  }

  /// Retrieves details and storage status of the host NVR.
  Future<ProtectNvr> getNvr() async {
    // Check /nvrs endpoint first, falling back to /nvr if needed
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/nvrs',
    );

    http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode == 404) {
      final Uri fallbackUri = options.baseUri.replace(
        path: '${options.baseUri.path}/nvr',
      );
      response = await client
          .get(fallbackUri, headers: options.headers)
          .timeout(options.requestTimeout);
    }

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getNvr',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is List<dynamic> &&
        decoded.isNotEmpty &&
        decoded.first is Map) {
      return ProtectNvr.fromJson(decoded.first as Map<String, dynamic>);
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];
      if (data is List<dynamic> && data.isNotEmpty) {
        return ProtectNvr.fromJson(
          data.first as Map<String, dynamic>,
        );
      }
      return ProtectNvr.fromJson(decoded);
    }

    throw const FormatException(
        'Expected JSON object or array for NVR details');
  }

  /// Partially updates NVR settings.
  Future<ProtectNvr> updateNvr(Map<String, dynamic> patch) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/nvrs',
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
        'UniFi Protect returned HTTP ${response.statusCode} for updateNvr',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getNvr();
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectNvr.fromJson(decoded as Map<String, dynamic>);
  }
}
