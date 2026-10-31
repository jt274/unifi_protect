import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../client/unifi_protect_options.dart';
import '../models/detection_type.dart';
import 'event_channel_adapter.dart';
import 'protect_event.dart';

/// Real-time event streaming subscription via UniFi Protect WebSocket.
class ProtectEventSubscription {
  ProtectEventSubscription({
    required this.options,
    this.reconnectInterval = const Duration(seconds: 10),
    this.channelFactory,
  });

  final UnifiProtectOptions options;
  final Duration reconnectInterval;

  /// Optional factory function for creating the underlying [WebSocketChannel].
  final Future<WebSocketChannel> Function(UnifiProtectOptions options)?
      channelFactory;

  final StreamController<ProtectEvent> _eventController =
      StreamController<ProtectEvent>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isDisposed = false;

  /// Stream of all real-time events (alerts, detections, device updates).
  Stream<ProtectEvent> get eventStream => _eventController.stream;

  /// Stream emitting boolean connection state changes (`true` = connected).
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Current connection state.
  bool get isConnected => _isConnected;

  /// Connects to the UniFi Protect WebSocket event stream.
  Future<bool> connect() async {
    if (_isDisposed) {
      return false;
    }
    _reconnectTimer?.cancel();
    await _closeChannel();

    try {
      final Future<WebSocketChannel> Function(UnifiProtectOptions options)
          connectFn = channelFactory ?? connectEventChannel;
      _channel = await connectFn(options);
      _setConnected(true);

      void onDisconnected([Object? _]) {
        _setConnected(false);
        _scheduleReconnect();
      }

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: onDisconnected,
        onDone: onDisconnected,
      );
      return true;
    } catch (_) {
      _setConnected(false);
      _scheduleReconnect();
      return false;
    }
  }

  void _handleMessage(dynamic data) {
    if (data is! String) {
      return;
    }
    try {
      final dynamic decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final Map<String, dynamic> item =
          decoded['item'] as Map<String, dynamic>? ?? decoded;
      final String? cameraId =
          (item['camera'] ?? item['cameraId'] ?? item['device'])?.toString();

      if (cameraId != null && cameraId.isNotEmpty) {
        final dynamic rawSmart = item['smartDetectTypes'];
        final String rawType = (item['type'] ??
                (rawSmart is List<dynamic> && rawSmart.isNotEmpty
                    ? rawSmart.first
                    : 'motion'))
            .toString();

        final ProtectDetectionType detectionType =
            ProtectDetectionType.fromString(rawType);
        final int? score = (item['score'] as num?)?.toInt();

        final ProtectAlertEvent event = ProtectAlertEvent(
          cameraId: cameraId,
          detectionType: detectionType,
          cameraName: item['cameraName']?.toString(),
          score: score,
          timestamp: DateTime.now(),
          rawPayload: decoded,
        );
        if (!_eventController.isClosed) {
          _eventController.add(event);
        }
        return;
      }

      final String? modelKey = item['modelKey']?.toString();
      final String? id = item['id']?.toString();
      final String action = decoded['action']?.toString() ?? 'update';
      if (modelKey != null && id != null) {
        final ProtectDeviceUpdateEvent updateEvent = ProtectDeviceUpdateEvent(
          modelKey: modelKey,
          deviceId: id,
          action: action,
          timestamp: DateTime.now(),
          rawPayload: decoded,
        );
        if (!_eventController.isClosed) {
          _eventController.add(updateEvent);
        }
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_isDisposed) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectInterval, () {
      if (!_isDisposed && !_isConnected) {
        connect();
      }
    });
  }

  void _setConnected(bool value) {
    if (_isConnected != value) {
      _isConnected = value;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(value);
      }
    }
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Disconnects from the WebSocket and cancels reconnect attempts.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await _closeChannel();
    _setConnected(false);
  }

  /// Closes the subscription and its stream controllers.
  Future<void> dispose() async {
    _isDisposed = true;
    await disconnect();
    await _eventController.close();
    await _connectionStateController.close();
  }
}
