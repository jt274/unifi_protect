import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/chime.dart';

/// Service for managing UniFi Protect smart chimes.
class ChimeService {
  ChimeService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Lists all adopted smart chimes.
  Future<List<ProtectChime>> listChimes() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/chimes',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for listChimes',
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
        .map(ProtectChime.fromJson)
        .toList();
  }

  /// Gets details for a specific chime by [id].
  Future<ProtectChime> getChime(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/chimes/$id',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getChime ($id)',
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectChime.fromJson(decoded as Map<String, dynamic>);
  }

  /// Updates settings for a chime (e.g. ringtone, volume, paired cameras).
  Future<ProtectChime> updateChime(
      String id, Map<String, dynamic> patch) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/chimes/$id',
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
      throw HttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for updateChime ($id)',
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getChime(id);
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectChime.fromJson(decoded as Map<String, dynamic>);
  }

  /// Triggers the chime buzzer for testing or alerts.
  Future<void> playBuzzer(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/chimes/$id/play-buzzer',
    );

    final http.Response response = await client
        .post(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw HttpException(
        'Failed to play chime buzzer for $id (HTTP ${response.statusCode})',
        uri: uri,
      );
    }
  }

  /// Sets the chime volume (0-100).
  Future<ProtectChime> setVolume(String id, int volume) {
    final int clamped = volume.clamp(0, 100);
    return updateChime(id, <String, dynamic>{'volume': clamped});
  }
}
