import 'dart:convert';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/exception.dart';
import '../models/viewer.dart';

/// Service for managing UniFi Protect ViewPort HDMI display devices.
class ViewerService {
  ViewerService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Lists all adopted ViewPort devices.
  Future<List<ProtectViewer>> listViewers() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/viewers',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for listViewers',
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
        .map(ProtectViewer.fromJson)
        .toList();
  }

  /// Gets details for a specific ViewPort by [id].
  Future<ProtectViewer> getViewer(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/viewers/$id',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getViewer ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectViewer.fromJson(decoded as Map<String, dynamic>);
  }

  /// Updates settings for a ViewPort.
  Future<ProtectViewer> updateViewer(
      String id, Map<String, dynamic> patch) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/viewers/$id',
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
        'UniFi Protect returned HTTP ${response.statusCode} for updateViewer ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getViewer(id);
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectViewer.fromJson(decoded as Map<String, dynamic>);
  }

  /// Assigns a live view layout to be displayed on this ViewPort.
  Future<ProtectViewer> assignLiveview(String id, String liveviewId) {
    return updateViewer(id, <String, dynamic>{'liveview': liveviewId});
  }
}
