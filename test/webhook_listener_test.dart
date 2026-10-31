import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

    test(
        'parseWebhookRequest parses query string triggers including active=false',
        () {
      final Uri uri = Uri.parse(
          'http://localhost:8765/api/webhook/trigger?camera=driveway&type=vehicle&active=false');
      final ProtectAlertEvent? alert =
          ProtectWebhookListener.parseWebhookRequest(
        uri: uri,
        bodyString: '',
      );

      expect(alert, isNotNull);
      expect(alert!.cameraId, equals('driveway'));
      expect(alert.detectionType, equals(ProtectDetectionType.vehicle));
      expect(alert.isActive, isFalse);
    });

    test(
        'parseWebhookRequest parses Alarm Manager JSON payload and various detection inferences',
        () {
      // 1. triggers with key
      final String payloadTriggers = jsonEncode(<String, dynamic>{
        'alarm': <String, dynamic>{
          'name': 'Person Alert',
          'triggers': <dynamic>[
            <String, dynamic>{
              'device': 'cam_front',
              'key': 'smartDetectZone.person',
            }
          ],
        },
      });

      final ProtectAlertEvent? alertTriggers =
          ProtectWebhookListener.parseWebhookRequest(
        uri: Uri.parse('http://localhost:8765/api/webhook/trigger'),
        bodyString: payloadTriggers,
      );
      expect(alertTriggers!.cameraId, equals('cam_front'));
      expect(alertTriggers.detectionType, equals(ProtectDetectionType.person));

      // 2. triggers fallback fields: cameraId, camera, deviceName
      for (final String field in <String>['cameraId', 'camera', 'deviceName']) {
        final String payload = jsonEncode(<String, dynamic>{
          'alarm': <String, dynamic>{
            'triggers': <dynamic>[
              <String, dynamic>{field: 'cam_fallback_$field'},
            ],
          },
        });
        final ProtectAlertEvent? alert =
            ProtectWebhookListener.parseWebhookRequest(
          uri: Uri.parse('http://localhost:8765/api/webhook/trigger'),
          bodyString: payload,
        );
        expect(alert!.cameraId, equals('cam_fallback_$field'));
      }

      // 3. sources fallback and alarm name detection
      final Map<String, ProtectDetectionType> alarmNames =
          <String, ProtectDetectionType>{
        'Driveway Vehicle Detected': ProtectDetectionType.vehicle,
        'Porch Package Delivered': ProtectDetectionType.package,
        'Yard Animal Sighted': ProtectDetectionType.animal,
        'Front Doorbell Ringing': ProtectDetectionType.ring,
      };

      for (final MapEntry<String, ProtectDetectionType> entry
          in alarmNames.entries) {
        final String payloadSources = jsonEncode(<String, dynamic>{
          'alarm': <String, dynamic>{
            'name': entry.key,
            'sources': <dynamic>[
              <String, dynamic>{'device': 'cam_yard'},
            ],
          },
          'isActive': false,
        });

        final ProtectAlertEvent? alert =
            ProtectWebhookListener.parseWebhookRequest(
          uri: Uri.parse('http://localhost:8765/api/webhook/trigger'),
          bodyString: payloadSources,
        );
        expect(alert!.cameraId, equals('cam_yard'));
        expect(alert.detectionType, equals(entry.value));
        expect(alert.isActive, isFalse);
      }

      // 4. sources with id when device is null
      final String payloadSourceId = jsonEncode(<String, dynamic>{
        'alarm': <String, dynamic>{
          'sources': <dynamic>[
            <String, dynamic>{'id': 'cam_from_source_id'},
          ],
        },
      });
      final ProtectAlertEvent? alertSourceId =
          ProtectWebhookListener.parseWebhookRequest(
        uri: Uri.parse('http://localhost:8765/api/webhook/trigger'),
        bodyString: payloadSourceId,
      );
      expect(alertSourceId!.cameraId, equals('cam_from_source_id'));

      // 5. direct top-level fields
      final String payloadDirect = jsonEncode(<String, dynamic>{
        'cameraId': 'cam_direct',
        'event': 'ring',
        'isActive': true,
      });
      final ProtectAlertEvent? alertDirect =
          ProtectWebhookListener.parseWebhookRequest(
        uri: Uri.parse('http://localhost:8765/api/webhook/trigger'),
        bodyString: payloadDirect,
      );
      expect(alertDirect!.cameraId, equals('cam_direct'));
      expect(alertDirect.detectionType, equals(ProtectDetectionType.ring));

      // 6. empty or missing camera returns null
      expect(
        ProtectWebhookListener.parseWebhookRequest(
          uri: Uri.parse('http://localhost:8765/api/webhook/trigger'),
          bodyString: '{"invalid": true}',
        ),
        isNull,
      );
    });

    test(
        'embedded HTTP server responds to health check, trigger, 404, invalid utf8, and handles bind error',
        () async {
      // Bind error returns false
      final bool startFailed = await listener.start(port: -1);
      expect(startFailed, isFalse);

      final bool started = await listener.start(port: 0); // Ephemeral port
      expect(started, isTrue);
      expect(listener.isListening, isTrue);
      final int port = listener.boundPort!;

      // 1. Health Check
      final http.Response healthResp = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/webhook/health'));
      expect(healthResp.statusCode, equals(200));
      final Map<String, dynamic> healthJson =
          jsonDecode(healthResp.body) as Map<String, dynamic>;
      expect(healthJson['status'], equals('ok'));

      // 2. Incoming Trigger
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

      // 3. 404 on unknown path
      final http.Response notFoundResp =
          await http.get(Uri.parse('http://127.0.0.1:$port/unknown/path'));
      expect(notFoundResp.statusCode, equals(404));

      // 4. Bad request handling with invalid UTF-8 bytes to trigger catch block
      final HttpClient client = HttpClient();
      final HttpClientRequest req = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/api/webhook/trigger'),
      );
      req.headers.contentType = ContentType.json;
      req.add(<int>[0xFF, 0xFE, 0xFD]); // Invalid UTF-8 sequence
      final HttpClientResponse resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.badRequest));
      client.close();

      await sub.cancel();
      await listener.stop();
      expect(listener.isListening, isFalse);
    });
  });
}
