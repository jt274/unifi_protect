import 'dart:convert';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/exception.dart';
import '../models/liveview.dart';

/// Service for managing UniFi Protect multi-camera live view layouts.
class LiveviewService {
  LiveviewService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Lists all configured live view layouts.
  Future<List<ProtectLiveview>> listLiveviews() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/liveviews',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for listLiveviews',
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
        .map(ProtectLiveview.fromJson)
        .toList();
  }

  /// Gets details for a specific live view layout by [id].
  Future<ProtectLiveview> getLiveview(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/liveviews/$id',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getLiveview ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectLiveview.fromJson(decoded as Map<String, dynamic>);
  }

  /// Creates a new live view layout.
  Future<ProtectLiveview> createLiveview(Map<String, dynamic> data) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/liveviews',
    );

    final http.Response response = await client
        .post(
          uri,
          headers: <String, String>{
            ...options.headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(data),
        )
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ProtectHttpException(
        'Failed to create live view (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectLiveview.fromJson(decoded as Map<String, dynamic>);
  }

  /// Updates an existing live view layout.
  Future<ProtectLiveview> updateLiveview(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/liveviews/$id',
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
        'UniFi Protect returned HTTP ${response.statusCode} for updateLiveview ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getLiveview(id);
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectLiveview.fromJson(decoded as Map<String, dynamic>);
  }

  /// Deletes a live view layout.
  Future<void> deleteLiveview(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/liveviews/$id',
    );

    final http.Response response = await client
        .delete(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw ProtectHttpException(
        'Failed to delete live view $id (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }
}
