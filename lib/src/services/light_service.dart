import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/light.dart';

/// Service for managing UniFi Protect smart floodlights.
class LightService {
  LightService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Lists all adopted floodlights.
  Future<List<ProtectLight>> listLights() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/lights',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for listLights',
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
        .map(ProtectLight.fromJson)
        .toList();
  }

  /// Gets details for a specific light by [id].
  Future<ProtectLight> getLight(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/lights/$id',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getLight ($id)',
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectLight.fromJson(decoded as Map<String, dynamic>);
  }

  /// Updates settings for a floodlight.
  Future<ProtectLight> updateLight(
      String id, Map<String, dynamic> patch) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/lights/$id',
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
        'UniFi Protect returned HTTP ${response.statusCode} for updateLight ($id)',
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getLight(id);
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectLight.fromJson(decoded as Map<String, dynamic>);
  }

  /// Turns the light LED on or off.
  Future<ProtectLight> setLed(String id, bool isLedOn) {
    return updateLight(id, <String, dynamic>{'isLedOn': isLedOn});
  }

  /// Adjusts the floodlight brightness level (1-100).
  Future<ProtectLight> setBrightness(String id, int brightness) {
    final int clamped = brightness.clamp(1, 100);
    return updateLight(id, <String, dynamic>{
      'lightDeviceSettings': <String, dynamic>{'ledLevel': clamped},
    });
  }
}
