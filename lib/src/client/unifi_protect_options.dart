/// Configuration options for connecting to UniFi Protect.
class UnifiProtectOptions {
  const UnifiProtectOptions({
    this.host = '192.168.1.1',
    this.port = 443,
    required this.apiKey,
    this.cloudConsoleId,
    this.allowSelfSignedCertificates = false,
    this.useSsl = true,
    this.requestTimeout = const Duration(seconds: 10),
  });

  /// Hostname or IP address of the local UniFi Console (e.g. Dream Machine, UNVR).
  final String host;

  /// HTTPS/HTTP port of the UniFi Console (default: 443).
  final int port;

  /// API Key generated in UniFi Site Manager (`Settings → API Keys`).
  final String apiKey;

  /// If provided, routes requests through the Ubiquiti Cloud Connector proxy at `api.ui.com`.
  final String? cloudConsoleId;

  /// Whether to permit self-signed SSL certificates when connecting directly to local consoles.
  ///
  /// Defaults to `false` for security. Set to `true` when connecting to local
  /// UniFi OS consoles that use the factory self-signed SSL certificate.
  /// This option is ignored when [isCloudMode] is true (`api.ui.com`).
  final bool allowSelfSignedCertificates;

  /// Whether to use HTTPS/WSS (true) or HTTP/WS (false).
  final bool useSsl;

  /// Default timeout for HTTP requests.
  final Duration requestTimeout;

  /// Whether this client connects via the Ubiquiti Cloud Connector proxy.
  bool get isCloudMode =>
      cloudConsoleId != null && cloudConsoleId!.trim().isNotEmpty;

  /// Clean host string stripped of scheme and trailing slashes.
  String get cleanHost {
    final String trimmed = host
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/')
        .first
        .split(':')
        .first;
    return trimmed.isEmpty ? '192.168.1.1' : trimmed;
  }

  /// Base URI for REST API calls.
  Uri get baseUri {
    if (isCloudMode) {
      return Uri.https(
        'api.ui.com',
        '/v1/connector/consoles/${cloudConsoleId!.trim()}/proxy/protect/integration/v1',
      );
    }
    return Uri(
      scheme: useSsl ? 'https' : 'http',
      host: cleanHost,
      port: port,
      path: '/proxy/protect/integration/v1',
    );
  }

  /// WebSocket URI for real-time event streaming.
  Uri get eventsWebSocketUri {
    return Uri(
      scheme: useSsl ? 'wss' : 'ws',
      host: cleanHost,
      port: port,
      path: '/proxy/protect/integration/v1/subscribe/events',
    );
  }

  /// Builds standard request headers including authentication.
  Map<String, String> get headers {
    return <String, String>{
      'X-API-KEY': apiKey.trim(),
      'Accept': 'application/json',
    };
  }
}
