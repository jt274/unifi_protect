import 'protect_event.dart';

export 'webhook_server_stub.dart' if (dart.library.io) 'webhook_server_io.dart';

/// Adapter interface for running a webhook HTTP server across platforms.
abstract class WebhookServerAdapter {
  /// Starts listening for webhooks.
  Future<bool> start({
    int port = 8765,
    Object? address,
    required void Function(ProtectAlertEvent) onEvent,
  });

  /// Stops the webhook server.
  Future<void> stop();

  /// Bound local TCP port of the webhook listener.
  int? get boundPort;

  /// Whether the webhook server is actively listening.
  bool get isListening;
}
