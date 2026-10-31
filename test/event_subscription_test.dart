import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

import 'test_certificates.dart';

void main() {
  group('ProtectEventSubscription', () {
    late HttpServer mockWsServer;
    late int serverPort;
    late Completer<WebSocket> serverSocketCompleter;

    setUp(() async {
      mockWsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = mockWsServer.port;
      serverSocketCompleter = Completer<WebSocket>();

      mockWsServer.transform(WebSocketTransformer()).listen((WebSocket socket) {
        socket.listen(
          (dynamic data) {},
          onError: (Object _) {},
        );
        socket.done.catchError((Object _) {});
        if (!serverSocketCompleter.isCompleted) {
          serverSocketCompleter.complete(socket);
        }
      });
    });

    tearDown(() async {
      await mockWsServer.close(force: true);
    });

    test(
        'receives and parses alert and update events over WebSocket and handles connection state',
        () async {
      final UnifiProtectOptions options = UnifiProtectOptions(
        host: '127.0.0.1',
        port: serverPort,
        apiKey: 'test-ws-key',
        useSsl: false,
      );

      final ProtectEventSubscription subscription = ProtectEventSubscription(
        options: options,
        reconnectInterval: const Duration(milliseconds: 10),
      );

      final List<ProtectEvent> events = <ProtectEvent>[];
      final List<bool> connectionStates = <bool>[];
      final Completer<void> eventsReceived = Completer<void>();

      final StreamSubscription<bool> connSub =
          subscription.connectionStateStream.listen(connectionStates.add);

      final StreamSubscription<ProtectEvent> sub =
          subscription.eventStream.listen((ProtectEvent event) {
        events.add(event);
        if (events.length == 3 && !eventsReceived.isCompleted) {
          eventsReceived.complete();
        }
      });

      final bool connected = await subscription.connect();
      expect(connected, isTrue);
      expect(subscription.isConnected, isTrue);

      final WebSocket serverSocket = await serverSocketCompleter.future;

      // 1. Send smart detection event with smartDetectTypes list fallback
      serverSocket.add(
        jsonEncode(<String, dynamic>{
          'item': <String, dynamic>{
            'camera': 'cam_driveway',
            'smartDetectTypes': <dynamic>['vehicle'],
            'score': 85,
          },
        }),
      );

      // 2. Send smart detection with explicit type
      serverSocket.add(
        jsonEncode(<String, dynamic>{
          'item': <String, dynamic>{
            'camera': 'cam_porch',
            'type': 'person',
            'score': 95,
            'cameraName': 'Porch Cam',
          },
        }),
      );

      // 3. Send device update event
      serverSocket.add(
        jsonEncode(<String, dynamic>{
          'action': 'update',
          'item': <String, String>{
            'modelKey': 'camera',
            'id': 'cam_driveway',
          },
        }),
      );

      // 4. Send non-json and non-map message (ignored without throwing)
      serverSocket.add('not_json_string');
      serverSocket.add('["array_not_map"]');

      await eventsReceived.future.timeout(const Duration(seconds: 3));

      expect(events, hasLength(3));

      final ProtectAlertEvent alert1 = events[0] as ProtectAlertEvent;
      expect(alert1.cameraId, equals('cam_driveway'));
      expect(alert1.detectionType, equals(ProtectDetectionType.vehicle));

      final ProtectAlertEvent alert2 = events[1] as ProtectAlertEvent;
      expect(alert2.cameraId, equals('cam_porch'));
      expect(alert2.cameraName, equals('Porch Cam'));

      final ProtectDeviceUpdateEvent update =
          events[2] as ProtectDeviceUpdateEvent;
      expect(update.modelKey, equals('camera'));
      expect(update.deviceId, equals('cam_driveway'));

      // 5. Test server socket close triggering reconnect logic
      await serverSocket.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await connSub.cancel();
      await sub.cancel();
      await subscription.dispose();

      // Connect when disposed returns false
      expect(await subscription.connect(), isFalse);
    });

    test('connects securely to wss with self-signed certificate', () async {
      final SecurityContext context = createTestSecurityContext();
      final HttpServer secureWsServer =
          await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
      secureWsServer.transform(WebSocketTransformer()).listen((WebSocket ws) {
        ws.add('{}');
      });

      try {
        final UnifiProtectOptions options = UnifiProtectOptions(
          host: '127.0.0.1',
          port: secureWsServer.port,
          apiKey: 'test-ws-key',
        );
        final ProtectEventSubscription subscription =
            ProtectEventSubscription(options: options);
        final bool connected = await subscription.connect();
        expect(connected, isTrue);
        await subscription.dispose();
      } finally {
        await secureWsServer.close(force: true);
      }
    });

    test('connect to invalid host returns false', () async {
      final ServerSocket temp =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final int closedPort = temp.port;
      await temp.close();

      final UnifiProtectOptions options = UnifiProtectOptions(
        host: '127.0.0.1',
        port: closedPort,
        apiKey: 'key',
        useSsl: false,
        requestTimeout: const Duration(milliseconds: 500),
      );
      final ProtectEventSubscription subscription = ProtectEventSubscription(
        options: options,
      );
      expect(await subscription.connect(), isFalse);
      expect(subscription.isConnected, isFalse);
      await subscription.dispose();
    });
  });
}
