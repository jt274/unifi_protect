import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unifi_protect/src/client/http_adapter_stub.dart' as http_stub;
import 'package:unifi_protect/src/events/event_channel_stub.dart'
    as event_channel_stub;
import 'package:unifi_protect/src/events/webhook_server_stub.dart'
    as webhook_stub;
import 'package:unifi_protect/unifi_protect.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('ProtectHttpException', () {
    test('fields and toString formatting work correctly', () {
      final Uri uri = Uri.parse('https://192.168.1.1/api');
      const ProtectHttpException ex1 = ProtectHttpException(
        'Not Found',
        statusCode: 404,
      );
      expect(ex1.message, equals('Not Found'));
      expect(ex1.statusCode, equals(404));
      expect(ex1.uri, isNull);
      expect(
          ex1.toString(), equals('ProtectHttpException: Not Found (HTTP 404)'));

      final ProtectHttpException ex2 = ProtectHttpException(
        'Server Error',
        statusCode: 500,
        uri: uri,
      );
      expect(
        ex2.toString(),
        equals(
            'ProtectHttpException: Server Error (HTTP 500), uri: https://192.168.1.1/api'),
      );

      const ProtectHttpException ex3 = ProtectHttpException('Unknown');
      expect(ex3.statusCode, isNull);
      expect(ex3.toString(), equals('ProtectHttpException: Unknown'));
    });
  });

  group('Web Platform Stubs', () {
    test('http_adapter_stub createHttpClient returns standard client', () {
      const UnifiProtectOptions options = UnifiProtectOptions(
        apiKey: 'test-key',
      );
      final http.Client client = http_stub.createHttpClient(options);
      expect(client, isNotNull);
      client.close();
    });

    test('event_channel_stub connectEventChannel connects to WebSocketUri',
        () async {
      final HttpServer server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.transform(WebSocketTransformer()).listen((WebSocket socket) {
        socket.listen((_) {});
      });

      final UnifiProtectOptions options = UnifiProtectOptions(
        apiKey: 'test-key',
        host: server.address.address,
        port: server.port,
        useSsl: false,
      );

      final WebSocketChannel channel =
          await event_channel_stub.connectEventChannel(options);
      expect(channel, isNotNull);
      channel.sink.add('ping');
      await channel.sink.close();
      await server.close(force: true);
    });

    test('webhook_server_stub handles unsupported server lifecycle', () async {
      final webhook_stub.WebhookServerStub stub =
          webhook_stub.createWebhookServer() as webhook_stub.WebhookServerStub;

      expect(stub.boundPort, isNull);
      expect(stub.isListening, isFalse);

      final bool started = await stub.start(
        onEvent: (ProtectAlertEvent event) {},
      );
      expect(started, isFalse);
      expect(stub.isListening, isFalse);

      await expectLater(stub.stop(), completes);
    });

    test('ProtectEventSubscription supports custom channelFactory', () async {
      final HttpServer server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.transform(WebSocketTransformer()).listen((WebSocket socket) {
        socket.listen((_) {});
      });

      bool factoryCalled = false;
      final UnifiProtectOptions options = UnifiProtectOptions(
        apiKey: 'test-key',
        host: server.address.address,
        port: server.port,
        useSsl: false,
      );

      final ProtectEventSubscription subscription = ProtectEventSubscription(
        options: options,
        channelFactory: (UnifiProtectOptions opts) async {
          factoryCalled = true;
          return event_channel_stub.connectEventChannel(opts);
        },
      );

      expect(subscription.channelFactory, isNotNull);
      final bool connected = await subscription.connect();
      expect(connected, isTrue);
      expect(factoryCalled, isTrue);

      await subscription.dispose();
      await server.close(force: true);
    });
  });
}
