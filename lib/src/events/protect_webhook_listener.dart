import 'dart:async';
import 'dart:convert';

import '../models/detection_type.dart';
import 'protect_event.dart';
import 'webhook_server_adapter.dart';

/// Embedded local HTTP server for receiving UniFi Protect Alarm Manager webhooks.
class ProtectWebhookListener {
  ProtectWebhookListener({WebhookServerAdapter? serverAdapter})
      : _adapter = serverAdapter ?? createWebhookServer();

  final WebhookServerAdapter _adapter;
  final StreamController<ProtectAlertEvent> _alertController =
      StreamController<ProtectAlertEvent>.broadcast();

  /// Stream of incoming parsed alert events from Alarm Manager webhooks.
  Stream<ProtectAlertEvent> get alertStream => _alertController.stream;

  /// Bound local TCP port of the webhook listener.
  int? get boundPort => _adapter.boundPort;

  /// Whether the webhook server is actively listening.
  bool get isListening => _adapter.isListening;

  /// Starts listening for webhooks on [port] (defaults to 8765, or 0 for ephemeral).
  ///
  /// On platforms without raw socket support (such as Web), this returns `false`.
  Future<bool> start({int port = 8765, Object? address}) async {
    return _adapter.start(
      port: port,
      address: address,
      onEvent: (ProtectAlertEvent event) {
        if (!_alertController.isClosed) {
          _alertController.add(event);
        }
      },
    );
  }

  /// Stops the webhook server.
  Future<void> stop() async {
    await _adapter.stop();
  }

  /// Parses incoming webhook query parameters and/or UniFi Protect Alarm Manager JSON payload.
  static ProtectAlertEvent? parseWebhookRequest({
    required Uri uri,
    required String bodyString,
  }) {
    String? cameraIdentifier =
        uri.queryParameters['camera'] ?? uri.queryParameters['cameraId'];
    String? rawDetectionType =
        uri.queryParameters['type'] ?? uri.queryParameters['event'];
    bool isActive = true;

    if (uri.queryParameters['active'] != null) {
      isActive = uri.queryParameters['active']!.toLowerCase() != 'false';
    }

    Map<String, dynamic> rawJson = const <String, dynamic>{};

    if (bodyString.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(bodyString);
        if (decoded is Map<String, dynamic>) {
          rawJson = decoded;
          cameraIdentifier ??= _extractCameraFromAlarmJson(decoded) ??
              decoded['camera'] as String? ??
              decoded['cameraId'] as String? ??
              decoded['device'] as String?;

          rawDetectionType ??= _extractDetectionFromAlarmJson(decoded) ??
              decoded['type'] as String? ??
              decoded['event'] as String?;

          if (decoded['isActive'] is bool) {
            isActive = decoded['isActive'] as bool;
          }
        }
      } catch (_) {}
    }

    final ProtectDetectionType detectionType = ProtectDetectionType.fromString(
      rawDetectionType ?? 'motion',
    );

    if (cameraIdentifier != null && cameraIdentifier.trim().isNotEmpty) {
      return ProtectAlertEvent(
        cameraId: cameraIdentifier.trim(),
        detectionType: detectionType,
        isActive: isActive,
        timestamp: DateTime.now(),
        rawPayload: rawJson,
      );
    }

    return null;
  }

  static String? _extractCameraFromAlarmJson(Map<String, dynamic> json) {
    final dynamic alarm = json['alarm'];
    if (alarm is Map<String, dynamic>) {
      final dynamic triggers = alarm['triggers'];
      if (triggers is List<dynamic> && triggers.isNotEmpty) {
        final dynamic first = triggers.first;
        if (first is Map<String, dynamic>) {
          return (first['device'] ??
                  first['cameraId'] ??
                  first['camera'] ??
                  first['deviceName'])
              ?.toString();
        }
      }
      final dynamic sources = alarm['sources'];
      if (sources is List<dynamic> && sources.isNotEmpty) {
        final dynamic first = sources.first;
        if (first is Map<String, dynamic>) {
          return (first['device'] ?? first['id'])?.toString();
        }
      }
    }
    return null;
  }

  static String? _extractDetectionFromAlarmJson(Map<String, dynamic> json) {
    final dynamic alarm = json['alarm'];
    if (alarm is Map<String, dynamic>) {
      final dynamic triggers = alarm['triggers'];
      if (triggers is List<dynamic> && triggers.isNotEmpty) {
        final dynamic first = triggers.first;
        if (first is Map<String, dynamic>) {
          return (first['key'] ?? first['type'] ?? first['event'])?.toString();
        }
      }
      if (alarm['name'] is String) {
        final String alarmName = (alarm['name'] as String).toLowerCase();
        if (alarmName.contains('person')) {
          return 'person';
        }
        if (alarmName.contains('vehicle')) {
          return 'vehicle';
        }
        if (alarmName.contains('package')) {
          return 'package';
        }
        if (alarmName.contains('animal')) {
          return 'animal';
        }
        if (alarmName.contains('ring') || alarmName.contains('doorbell')) {
          return 'ring';
        }
      }
    }
    return null;
  }

  /// Closes the webhook listener and its streams.
  Future<void> dispose() async {
    await stop();
    await _alertController.close();
  }
}
