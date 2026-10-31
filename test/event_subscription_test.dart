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

    setUp(() async {
      mockWsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = mockWsServer.port;

      mockWsServer.transform(WebSocketTransformer()).listen((WebSocket socket) {
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

    test('receives and parses alert and update events over WebSocket',
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
      final Completer<void> twoEventsReceived = Completer<void>();
      final StreamSubscription<ProtectEvent> sub =
          subscription.eventStream.listen((ProtectEvent event) {
        events.add(event);
        if (events.length == 2 && !twoEventsReceived.isCompleted) {
          twoEventsReceived.complete();
        }
      });

      final bool connected = await subscription.connect();
      expect(connected, isTrue);
      expect(subscription.isConnected, isTrue);

      // Send a simulated smart detection event
      clientSocketController?.add(
        jsonEncode(<String, Map<String, Object>>{
          'item': <String, Object>{
            'camera': 'cam_driveway',
            'type': 'person',
            'score': 95,
            'cameraName': 'Driveway Camera',
          },
        }),
      );

      // Send a simulated device update event
      clientSocketController?.add(
        jsonEncode(<String, Object>{
          'action': 'update',
          'item': <String, String>{
            'modelKey': 'camera',
            'id': 'cam_driveway',
          },
        }),
      );

      await twoEventsReceived.future.timeout(const Duration(seconds: 3));

      expect(events, hasLength(2));

      final ProtectAlertEvent alert = events[0] as ProtectAlertEvent;
      expect(alert.cameraId, equals('cam_driveway'));
      expect(alert.detectionType, equals(ProtectDetectionType.person));
      expect(alert.score, equals(95));
      expect(alert.isSmartAlert, isTrue);

      final ProtectDeviceUpdateEvent update =
          events[1] as ProtectDeviceUpdateEvent;
      expect(update.modelKey, equals('camera'));
      expect(update.deviceId, equals('cam_driveway'));
      expect(update.action, equals('update'));

      await sub.cancel();
      await subscription.dispose();
    });
  });
}
