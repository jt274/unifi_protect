import 'package:http/http.dart' as http;

import '../events/protect_event_subscription.dart';
import '../events/protect_webhook_listener.dart';
import '../services/alarm_manager_service.dart';
import '../services/camera_service.dart';
import '../services/chime_service.dart';
import '../services/light_service.dart';
import '../services/liveview_service.dart';
import '../services/nvr_service.dart';
import '../services/sensor_service.dart';
import '../services/viewer_service.dart';
import 'http_adapter.dart';
import 'unifi_protect_options.dart';

/// The primary client for interacting with the Ubiquiti UniFi Protect Integration API.
class UnifiProtectClient {
  /// Creates a [UnifiProtectClient] instance configured with [options].
  ///
  /// Optionally accepts a custom [httpClient] implementation.
  UnifiProtectClient({
    required this.options,
    http.Client? httpClient,
  })  : _customClient = httpClient,
        _client = httpClient ?? createHttpClient(options) {
    cameras = CameraService(options: options, client: _client);
    lights = LightService(options: options, client: _client);
    sensors = SensorService(options: options, client: _client);
    chimes = ChimeService(options: options, client: _client);
    viewers = ViewerService(options: options, client: _client);
    liveviews = LiveviewService(options: options, client: _client);
    nvr = NvrService(options: options, client: _client);
    alarmManager = AlarmManagerService(options: options, client: _client);
    events = ProtectEventSubscription(options: options);
  }

  /// Active connection options.
  final UnifiProtectOptions options;

  final http.Client? _customClient;
  final http.Client _client;

  /// Cameras, video streams, snapshots, and PTZ controls.
  late final CameraService cameras;

  /// Smart floodlights.
  late final LightService lights;

  /// Multi-functional environmental and security sensors.
  late final SensorService sensors;

  /// Smart chimes.
  late final ChimeService chimes;

  /// ViewPort display devices.
  late final ViewerService viewers;

  /// Multi-camera grid live view layouts.
  late final LiveviewService liveviews;

  /// Protect application metadata and NVR system details.
  late final NvrService nvr;

  /// Alarm Manager webhooks.
  late final AlarmManagerService alarmManager;

  /// Real-time event streaming WebSocket.
  late final ProtectEventSubscription events;

  /// Creates a local embedded HTTP server to listen for webhooks from Protect Alarm Manager.
  ProtectWebhookListener createWebhookListener() {
    return ProtectWebhookListener();
  }

  /// Closes the HTTP client and terminates real-time subscriptions.
  Future<void> close() async {
    await events.dispose();
    if (_customClient == null) {
      _client.close();
    }
  }
}
