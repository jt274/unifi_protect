import 'dart:convert';
import 'dart:io';

import 'protect_event.dart';
import 'protect_webhook_listener.dart';
import 'webhook_server_adapter.dart';

/// Creates the platform-specific [WebhookServerAdapter] for IO/VM.
WebhookServerAdapter createWebhookServer() => WebhookServerIo();

/// Native [HttpServer] implementation of [WebhookServerAdapter].
class WebhookServerIo implements WebhookServerAdapter {
  HttpServer? _server;

  @override
  int? get boundPort => _server?.port;

  @override
  bool get isListening => _server != null;

  @override
  Future<bool> start({
    int port = 8765,
    Object? address,
    required void Function(ProtectAlertEvent) onEvent,
  }) async {
    await stop();
    try {
      final dynamic bindAddress = address ?? InternetAddress.anyIPv4;
      _server = await HttpServer.bind(
        bindAddress,
        port,
        shared: true,
      );
      _server!
          .listen((HttpRequest request) => _handleRequest(request, onEvent));
      return true;
    } catch (_) {
      _server = null;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }

  Future<void> _handleRequest(
    HttpRequest request,
    void Function(ProtectAlertEvent) onEvent,
  ) async {
    final String path = request.uri.path;

    if (request.method == 'GET' && path == '/api/webhook/health') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'status': 'ok',
            'port': boundPort,
          }),
        );
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path.startsWith('/api/webhook/trigger')) {
      try {
        final String bodyString = await utf8.decoder.bind(request).join();
        final ProtectAlertEvent? event =
            ProtectWebhookListener.parseWebhookRequest(
          uri: request.uri,
          bodyString: bodyString,
        );

        if (event != null) {
          onEvent(event);
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, dynamic>{
              'status': 'triggered',
              'matched': event != null,
              'cameraId': event?.cameraId,
              'detectionType': event?.detectionType.name,
            }),
          );
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, dynamic>{'error': e.toString()}));
      } finally {
        await request.response.close();
      }
      return;
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not Found');
    await request.response.close();
  }
}
