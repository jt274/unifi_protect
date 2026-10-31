import 'protect_event.dart';
import 'webhook_server_adapter.dart';

/// Creates the platform-specific [WebhookServerAdapter] for platforms without dart:io.
WebhookServerAdapter createWebhookServer() => WebhookServerStub();

/// Non-IO stub implementation of [WebhookServerAdapter].
class WebhookServerStub implements WebhookServerAdapter {
  @override
  int? get boundPort => null;

  @override
  bool get isListening => false;

  @override
  Future<bool> start({
    int port = 8765,
    Object? address,
    required void Function(ProtectAlertEvent) onEvent,
  }) async {
    // Embedded HTTP server is unsupported in browser/web environments.
    return false;
  }

  @override
  Future<void> stop() async {}
}
