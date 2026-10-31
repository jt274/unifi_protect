import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  group('ProtectWebhookListener', () {
    late ProtectWebhookListener listener;

    setUp(() {
      listener = ProtectWebhookListener();
    });

    tearDown(() async {
      await listener.dispose();
    });

    test('parseWebhookRequest parses query string triggers', () {
      final Uri uri = Uri.parse(
          'http://localhost:8765/api/webhook/trigger?camera=driveway&type=vehicle');
      final ProtectAlertEvent? alert =
          ProtectWebhookListener.parseWebhookRequest(
        uri: uri,
        bodyString: '',
      );

      expect(alert, isNotNull);
      expect(alert!.cameraId, equals('driveway'));
      expect(alert.detectionType, equals(ProtectDetectionType.vehicle));
      expect(alert.isActive, isTrue);
    });

    test('parseWebhookRequest parses Alarm Manager JSON payload', () {
      final Uri uri = Uri.parse('http://localhost:8765/api/webhook/trigger');
      final String payload = jsonEncode(<String, Map<String, Object>>{
        'alarm': <String, Object>{
          'name': 'Person detected at Front Door',
          'triggers': <Map<String, String>>[
            <String, String>{
              'device': 'cam_front',
              'key': 'smartDetectZone.person'
            }
          ],
        },
      });

      final ProtectAlertEvent? alert =
          ProtectWebhookListener.parseWebhookRequest(
        uri: uri,
        bodyString: payload,
      );

      expect(alert, isNotNull);
      expect(alert!.cameraId, equals('cam_front'));
      expect(alert.detectionType, equals(ProtectDetectionType.person));
      expect(alert.isActive, isTrue);
    });

    test(
        'embedded HTTP server responds to health check and emits alerts on POST',
        () async {
      final bool started = await listener.start(port: 0); // Ephemeral port
      expect(started, isTrue);
      expect(listener.isListening, isTrue);
      final int port = listener.boundPort!;

      // 1. Test Health Check
      final http.Response healthResp = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/webhook/health'));
      expect(healthResp.statusCode, equals(200));
      final Map<String, dynamic> healthJson =
          jsonDecode(healthResp.body) as Map<String, dynamic>;
      expect(healthJson['status'], equals('ok'));

      // 2. Test Incoming Trigger
      final Completer<ProtectAlertEvent> alertReceived =
          Completer<ProtectAlertEvent>();
      final StreamSubscription<ProtectAlertEvent> sub =
          listener.alertStream.listen((ProtectAlertEvent event) {
        if (!alertReceived.isCompleted) {
          alertReceived.complete(event);
        }
      });

      final http.Response triggerResp = await http.post(
        Uri.parse(
            'http://127.0.0.1:$port/api/webhook/trigger?camera=backyard&type=animal'),
      );
      expect(triggerResp.statusCode, equals(200));

      final ProtectAlertEvent alert =
          await alertReceived.future.timeout(const Duration(seconds: 3));
      expect(alert.cameraId, equals('backyard'));
      expect(alert.detectionType, equals(ProtectDetectionType.animal));

      await sub.cancel();
    });
  });
}
