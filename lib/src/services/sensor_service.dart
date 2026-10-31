import 'dart:convert';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/exception.dart';
import '../models/sensor.dart';

/// Service for monitoring and configuring UniFi Protect multi-sensors.
class SensorService {
  SensorService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Lists all adopted smart sensors.
  Future<List<ProtectSensor>> listSensors() async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/sensors',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for listSensors',
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
        .map(ProtectSensor.fromJson)
        .toList();
  }

  /// Gets details for a specific sensor by [id].
  Future<ProtectSensor> getSensor(String id) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/sensors/$id',
    );

    final http.Response response = await client
        .get(uri, headers: options.headers)
        .timeout(options.requestTimeout);

    if (response.statusCode != 200) {
      throw ProtectHttpException(
        'UniFi Protect returned HTTP ${response.statusCode} for getSensor ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectSensor.fromJson(decoded as Map<String, dynamic>);
  }

  /// Updates settings for a sensor (e.g. thresholds, paired camera).
  Future<ProtectSensor> updateSensor(
      String id, Map<String, dynamic> patch) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/sensors/$id',
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
        'UniFi Protect returned HTTP ${response.statusCode} for updateSensor ($id)',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return getSensor(id);
    }

    final dynamic decoded = jsonDecode(response.body);
    return ProtectSensor.fromJson(decoded as Map<String, dynamic>);
  }
}
