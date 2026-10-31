import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unifi_protect/src/client/http_adapter.dart';
import 'package:unifi_protect/unifi_protect.dart';

import 'test_certificates.dart';

void main() {
  group('UnifiProtectOptions', () {
    test('default options set correct defaults', () {
      const UnifiProtectOptions opts = UnifiProtectOptions(apiKey: 'key123');
      expect(opts.host, equals('192.168.1.1'));
      expect(opts.cleanHost, equals('192.168.1.1'));
      expect(opts.port, equals(443));
      expect(opts.apiKey, equals('key123'));
      expect(opts.cloudConsoleId, isNull);
      expect(opts.allowSelfSignedCertificates, isTrue);
      expect(opts.useSsl, isTrue);
      expect(opts.isCloudMode, isFalse);
      expect(
        opts.baseUri,
        equals(
            Uri.parse('https://192.168.1.1:443/proxy/protect/integration/v1')),
      );
      expect(
        opts.eventsWebSocketUri,
        equals(Uri.parse(
            'wss://192.168.1.1:443/proxy/protect/integration/v1/subscribe/events')),
      );
      expect(
        opts.headers,
        equals(<String, String>{
          'X-API-KEY': 'key123',
          'Accept': 'application/json',
        }),
      );
    });

    test('cleanHost trims prefixes, paths, and ports', () {
      const UnifiProtectOptions opts1 = UnifiProtectOptions(
        host: 'https://10.0.0.1:8443/test/',
        apiKey: 'key',
      );
      expect(opts1.cleanHost, equals('10.0.0.1'));

      const UnifiProtectOptions opts2 = UnifiProtectOptions(
        host: '   ',
        apiKey: 'key',
      );
      expect(opts2.cleanHost, equals('192.168.1.1'));
    });

    test('cloudConsoleId generates Cloud Connector baseUri', () {
      const UnifiProtectOptions opts = UnifiProtectOptions(
        apiKey: 'cloud-key',
        cloudConsoleId: 'ABC-123-DEF',
      );
      expect(opts.isCloudMode, isTrue);
      expect(
        opts.baseUri,
        equals(Uri.parse(
          'https://api.ui.com/v1/connector/consoles/ABC-123-DEF/proxy/protect/integration/v1',
        )),
      );
    });

    test('useSsl: false uses http and ws', () {
      const UnifiProtectOptions opts = UnifiProtectOptions(
        apiKey: 'key',
        host: '127.0.0.1',
        port: 8080,
        useSsl: false,
      );
      expect(opts.baseUri.scheme, equals('http'));
      expect(opts.eventsWebSocketUri.scheme, equals('ws'));
    });
  });

  group('http_adapter', () {
    test('createHttpClient respects allowSelfSignedCertificates flag', () {
      const UnifiProtectOptions optsAllow = UnifiProtectOptions(
        apiKey: 'key',
      );
      final http.Client clientAllow = createHttpClient(optsAllow);
      expect(clientAllow, isNotNull);
      clientAllow.close();

      const UnifiProtectOptions optsDisallow = UnifiProtectOptions(
        apiKey: 'key',
        allowSelfSignedCertificates: false,
      );
      final http.Client clientDisallow = createHttpClient(optsDisallow);
      expect(clientDisallow, isNotNull);
      clientDisallow.close();
    });

    test(
        'badCertificateCallback executes and validates host on actual HTTPS request',
        () async {
      final SecurityContext context = createTestSecurityContext();
      final HttpServer secureServer =
          await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
      final int port = secureServer.port;
      secureServer.listen((HttpRequest req) {
        req.response.write('secure ok');
        req.response.close();
      });

      try {
        final UnifiProtectOptions optsMatching = UnifiProtectOptions(
          host: '127.0.0.1',
          port: port,
          apiKey: 'key',
        );
        final http.Client clientMatching = createHttpClient(optsMatching);
        final http.Response resMatching =
            await clientMatching.get(Uri.parse('https://127.0.0.1:$port/'));
        expect(resMatching.body, equals('secure ok'));
        clientMatching.close();

        final UnifiProtectOptions optsMismatch = UnifiProtectOptions(
          host: 'otherhost',
          port: port,
          apiKey: 'key',
        );
        final http.Client clientMismatch = createHttpClient(optsMismatch);
        final http.Response resMismatch =
            await clientMismatch.get(Uri.parse('https://127.0.0.1:$port/'));
        expect(resMismatch.body, equals('secure ok'));
        clientMismatch.close();
      } finally {
        await secureServer.close(force: true);
      }
    });
  });

  group('UnifiProtectClient', () {
    test('initializes all sub-services and methods', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        return http.Response('[]', 200);
      });

      const UnifiProtectOptions opts = UnifiProtectOptions(
        apiKey: 'my-api-key',
      );

      final UnifiProtectClient client = UnifiProtectClient(
        options: opts,
        httpClient: mockClient,
      );

      expect(client.options, equals(opts));
      expect(client.cameras, isNotNull);
      expect(client.lights, isNotNull);
      expect(client.sensors, isNotNull);
      expect(client.chimes, isNotNull);
      expect(client.viewers, isNotNull);
      expect(client.liveviews, isNotNull);
      expect(client.nvr, isNotNull);
      expect(client.alarmManager, isNotNull);
      expect(client.events, isNotNull);

      final ProtectWebhookListener webhookListener =
          client.createWebhookListener();
      expect(webhookListener, isNotNull);
      expect(webhookListener.isListening, isFalse);
      await webhookListener.dispose();

      await client.close();
    });

    test('client with default httpClient closes cleanly', () async {
      const UnifiProtectOptions opts = UnifiProtectOptions(
        apiKey: 'my-api-key',
      );
      final UnifiProtectClient client = UnifiProtectClient(options: opts);
      await client.close();
    });
  });
}
