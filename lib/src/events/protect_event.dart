import '../models/detection_type.dart';

/// Base class for all real-time events emitted by UniFi Protect.
abstract class ProtectEvent {
  const ProtectEvent({
    required this.timestamp,
    required this.rawPayload,
  });

  /// Event creation timestamp.
  final DateTime timestamp;

  /// Original raw JSON payload.
  final Map<String, dynamic> rawPayload;
}

/// Real-time motion or smart alert event associated with a specific camera.
class ProtectAlertEvent extends ProtectEvent {
  const ProtectAlertEvent({
    required this.cameraId,
    required this.detectionType,
    this.cameraName,
    this.score,
    this.isActive = true,
    required super.timestamp,
    super.rawPayload = const <String, dynamic>{},
  });

  /// The camera identifier (MongoDB ObjectId or name).
  final String cameraId;

  /// Detection type (motion, person, vehicle, package, animal, ring, etc.).
  final ProtectDetectionType detectionType;

  /// Human-friendly camera name if available.
  final String? cameraName;

  /// Confidence score (0-100) for smart detections, if provided by Protect.
  final int? score;

  /// `true` when the detection starts/is active, `false` when cleared.
  final bool isActive;

  /// Whether this is a high-priority smart alert (person, vehicle, package, ring) vs general motion.
  bool get isSmartAlert =>
      detectionType == ProtectDetectionType.person ||
      detectionType == ProtectDetectionType.vehicle ||
      detectionType == ProtectDetectionType.package ||
      detectionType == ProtectDetectionType.ring;

  @override
  String toString() =>
      'ProtectAlertEvent(camera: $cameraId, type: ${detectionType.name}, active: $isActive)';
}

/// Emitted when a device state updates (e.g. online/offline, settings modified).
class ProtectDeviceUpdateEvent extends ProtectEvent {
  const ProtectDeviceUpdateEvent({
    required this.modelKey,
    required this.deviceId,
    required this.action,
    required super.timestamp,
    super.rawPayload = const <String, dynamic>{},
  });

  final String modelKey;
  final String deviceId;
  final String action;

  @override
  String toString() =>
      'ProtectDeviceUpdateEvent(model: $modelKey, device: $deviceId, action: $action)';
}
