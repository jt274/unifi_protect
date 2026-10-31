import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../client/unifi_protect_options.dart';

/// Connects to the UniFi Protect WebSocket endpoint using [dart:io] WebSockets.
Future<WebSocketChannel> connectEventChannel(
    UnifiProtectOptions options) async {
  final Uri wsUri = options.eventsWebSocketUri;
  final HttpClient customClient = HttpClient();
  if (options.allowSelfSignedCertificates && !options.isCloudMode) {
    customClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      final String normalizedHost = host.toLowerCase().trim();
      final String targetHost = options.cleanHost.toLowerCase().trim();
      return normalizedHost == targetHost;
    };
  }

  final WebSocket socket = await WebSocket.connect(
    wsUri.toString(),
    headers: <String, dynamic>{
      'X-API-KEY': options.apiKey.trim(),
    },
    customClient: customClient,
  ).timeout(options.requestTimeout);

  return IOWebSocketChannel(socket);
}
