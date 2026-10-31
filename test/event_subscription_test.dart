import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  group('ProtectEventSubscription', () {
    late HttpServer mockWsServer;
    late int serverPort;
    StreamController<String>? clientSocketController;
    WebSocket? serverSocket;

    setUp(() async {
      mockWsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = mockWsServer.port;

      mockWsServer.transform(WebSocketTransformer()).listen((WebSocket socket) {
        serverSocket = socket;
        socket.done.catchError((Object _) {});
        clientSocketController = StreamController<String>();
        clientSocketController!.stream.listen((String msg) {
          socket.add(msg);
        });
      });
    });

    tearDown(() async {
      await clientSocketController?.close();
      await mockWsServer.close(force: true);
    });

    test('receives and parses alert and update events over WebSocket and handles connection state',
        () async {
      final UnifiProtectOptions options = UnifiProtectOptions(
        host: '127.0.0.1',
        port: serverPort,
        apiKey: 'test-ws-key',
        useSsl: false,
      );

      final ProtectEventSubscription subscription = ProtectEventSubscription(
        options: options,
        reconnectInterval: const Duration(milliseconds: 100),
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

      // 1. Send smart detection event with smartDetectTypes list fallback
      clientSocketController?.add(
        jsonEncode(<String, dynamic>{
          'item': <String, dynamic>{
            'camera': 'cam_driveway',
            'smartDetectTypes': <dynamic>['vehicle'],
            'score': 85,
          },
        }),
      );

      // 2. Send smart detection with explicit type
      clientSocketController?.add(
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
      clientSocketController?.add(
        jsonEncode(<String, dynamic>{
          'action': 'update',
          'item': <String, String>{
            'modelKey': 'camera',
            'id': 'cam_driveway',
          },
        }),
      );

      // 4. Send non-json and non-map message (ignored without throwing)
      clientSocketController?.add('not_json_string');
      clientSocketController?.add('["array_not_map"]');

      await eventsReceived.future.timeout(const Duration(seconds: 3));

      expect(events, hasLength(3));

      final ProtectAlertEvent alert1 = events[0] as ProtectAlertEvent;
      expect(alert1.cameraId, equals('cam_driveway'));
      expect(alert1.detectionType, equals(ProtectDetectionType.vehicle));

      final ProtectAlertEvent alert2 = events[1] as ProtectAlertEvent;
      expect(alert2.cameraId, equals('cam_porch'));
      expect(alert2.cameraName, equals('Porch Cam'));

      final ProtectDeviceUpdateEvent update = events[2] as ProtectDeviceUpdateEvent;
      expect(update.modelKey, equals('camera'));
      expect(update.deviceId, equals('cam_driveway'));

      // 5. Test server socket close triggering reconnect logic
      await serverSocket?.close();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await connSub.cancel();
      await sub.cancel();
      await subscription.dispose();

      // Connect when disposed returns false
      expect(await subscription.connect(), isFalse);
    });

    test('connects securely to wss with self-signed certificate', () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('wss_test_');
      final String certPath = '${tempDir.path}/cert.pem';
      final String keyPath = '${tempDir.path}/key.pem';
      Process.runSync('openssl', <String>[
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-keyout',
        keyPath,
        '-out',
        certPath,
        '-days',
        '1',
        '-nodes',
        '-subj',
        '/CN=localhost',
      ]);
      final SecurityContext context = SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath);
      final HttpServer secureWsServer =
          await HttpServer.bindSecure('localhost', 0, context);
      secureWsServer.transform(WebSocketTransformer()).listen((WebSocket ws) {
        ws.add('{}');
      });

      try {
        final UnifiProtectOptions options = UnifiProtectOptions(
          host: 'localhost',
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
        tempDir.deleteSync(recursive: true);
      }
    });

    test('connect to invalid host returns false', () async {
      const UnifiProtectOptions options = UnifiProtectOptions(
        host: '127.0.0.1',
        port: 1, // Closed port
        apiKey: 'key',
        useSsl: false,
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
