import 'dart:convert';

import 'package:http/http.dart' as http;

import '../client/unifi_protect_options.dart';
import '../models/exception.dart';

/// Service for interacting with UniFi Protect Alarm Manager webhooks.
class AlarmManagerService {
  AlarmManagerService({
    required this.options,
    required this.client,
  });

  final UnifiProtectOptions options;
  final http.Client client;

  /// Triggers a webhook configured in UniFi Protect Alarm Manager by [webhookId].
  Future<void> triggerAlarmWebhook(
    String webhookId, [
    Map<String, dynamic>? payload,
  ]) async {
    final Uri uri = options.baseUri.replace(
      path: '${options.baseUri.path}/alarm-manager/webhook/$webhookId',
    );

    final http.Response response = await client
        .post(
          uri,
          headers: <String, String>{
            ...options.headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload ?? <String, dynamic>{}),
        )
        .timeout(options.requestTimeout);

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw ProtectHttpException(
        'Failed to trigger Alarm Manager webhook $webhookId (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }
}
