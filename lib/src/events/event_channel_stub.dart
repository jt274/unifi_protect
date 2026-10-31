import 'package:web_socket_channel/web_socket_channel.dart';

import '../client/unifi_protect_options.dart';

/// Connects to the UniFi Protect WebSocket endpoint on Web platforms.
Future<WebSocketChannel> connectEventChannel(
    UnifiProtectOptions options) async {
  return WebSocketChannel.connect(options.eventsWebSocketUri);
}
