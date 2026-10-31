import 'channel.dart';
import 'detection_type.dart';
import 'stream_quality.dart';

/// Represents a UniFi Protect camera or doorbell device.
class ProtectCamera {
  const ProtectCamera({
    required this.id,
    required this.name,
    required this.type,
    this.marketName,
    this.modelKey,
    this.isDoorbell = false,
    this.hasPackageCamera = false,
    this.hasSmartDetect = false,
    this.hasChime = false,
    this.hasSpeaker = false,
    this.hasMicrophone = false,
    this.hasPtz = false,
    this.isOnline = true,
    this.smartDetectTypes = const <ProtectDetectionType>{},
    this.channels = const <CameraChannel>[],
    this.aspectRatio,
    this.rawJson = const <String, dynamic>{},
  });

  factory ProtectCamera.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String name = json['name']?.toString() ?? 'UniFi Camera';
    final String type = json['type']?.toString() ?? '';
    final String? marketName = json['marketName']?.toString();
    final String? modelKey = json['modelKey']?.toString();

    final Map<String, dynamic> featureFlags =
        json['featureFlags'] is Map<String, dynamic>
            ? json['featureFlags'] as Map<String, dynamic>
            : const <String, dynamic>{};

    final dynamic rawChannels = json['channels'];
    final List<CameraChannel> channels = <CameraChannel>[];
    if (rawChannels is List<dynamic>) {
      for (final dynamic raw in rawChannels) {
        if (raw is Map<String, dynamic>) {
          channels.add(CameraChannel.fromJson(raw));
        }
      }
    }

    final String combinedModelStr =
        '${marketName ?? ''} $type $name'.toLowerCase();
    final bool isDoorbell = json['isDoorbell'] == true ||
        featureFlags['hasChime'] == true ||
        combinedModelStr.contains('doorbell');

    final bool hasPackageCamera = json['hasPackageCamera'] == true ||
        featureFlags['hasPackageCamera'] == true ||
        combinedModelStr.contains('doorbell pro') ||
        channels
            .any((CameraChannel c) => c.name.toLowerCase().contains('package'));

    final bool hasSmartDetect = featureFlags['hasSmartDetect'] == true ||
        json['hasSmartDetect'] == true;

    final dynamic smartTypesRaw = featureFlags['smartDetectTypes'] ??
        json['smartDetectTypes'] ??
        (json['smartDetectSettings'] is Map<String, dynamic>
            ? (json['smartDetectSettings']
                as Map<String, dynamic>)['objectTypes']
            : null);

    final Set<ProtectDetectionType> smartDetectTypes = <ProtectDetectionType>{};
    if (smartTypesRaw is List<dynamic>) {
      for (final dynamic item in smartTypesRaw) {
        smartDetectTypes.add(ProtectDetectionType.fromString(item.toString()));
      }
    } else if (hasSmartDetect) {
      smartDetectTypes.add(ProtectDetectionType.person);
      smartDetectTypes.add(ProtectDetectionType.vehicle);
    }

    final bool hasPtz =
        featureFlags['hasPtz'] == true || combinedModelStr.contains('ptz');

    final bool hasSpeaker =
        featureFlags['hasSpeaker'] == true || json['hasSpeaker'] == true;

    final bool hasMicrophone = featureFlags['hasMic'] == true ||
        featureFlags['hasMicrophone'] == true ||
        json['hasMic'] == true;

    final String? stateStr = json['state']?.toString().toUpperCase();
    final bool isOnline = stateStr == null || stateStr == 'CONNECTED';

    // Calculate aspect ratio from first channel with dimensions, or default based on device type
    double? calculatedAr;
    for (final CameraChannel ch in channels) {
      if (ch.aspectRatio != null) {
        calculatedAr = ch.aspectRatio;
        break;
      }
    }
    calculatedAr ??= isDoorbell ? (4.0 / 3.0) : (16.0 / 9.0);

    return ProtectCamera(
      id: id,
      name: name,
      type: type,
      marketName: marketName,
      modelKey: modelKey,
      isDoorbell: isDoorbell,
      hasPackageCamera: hasPackageCamera,
      hasSmartDetect: hasSmartDetect,
      hasChime: isDoorbell || featureFlags['hasChime'] == true,
      hasSpeaker: hasSpeaker,
      hasMicrophone: hasMicrophone,
      hasPtz: hasPtz,
      isOnline: isOnline,
      smartDetectTypes: smartDetectTypes,
      channels: channels,
      aspectRatio: calculatedAr,
      rawJson: json,
    );
  }

  /// Unique 24-character hexadecimal MongoDB ObjectId identifier.
  final String id;

  /// User-defined display name.
  final String name;

  /// Hardware type string (e.g. 'UVC G4 Doorbell Pro', 'UVC AI Pro', 'UVC G5 Bullet').
  final String type;

  /// Marketing name if provided by Protect.
  final String? marketName;

  /// Model key if provided.
  final String? modelKey;

  /// Whether this camera is a doorbell device.
  final bool isDoorbell;

  /// Whether this device features a secondary package camera (e.g. G4 Doorbell Pro).
  final bool hasPackageCamera;

  /// Whether this camera supports AI smart detections.
  final bool hasSmartDetect;

  /// Whether this camera has an integrated chime.
  final bool hasChime;

  /// Whether this camera has an integrated 2-way audio speaker.
  final bool hasSpeaker;

  /// Whether this camera has an integrated microphone.
  final bool hasMicrophone;

  /// Whether this camera supports Pan-Tilt-Zoom (PTZ) controls.
  final bool hasPtz;

  /// Whether the camera is currently connected and reporting online.
  final bool isOnline;

  /// Specific smart detection types supported by this camera hardware.
  final Set<ProtectDetectionType> smartDetectTypes;

  /// Available video channels on this camera (e.g. High, Medium, Low, Package).
  final List<CameraChannel> channels;

  /// Physical or stream aspect ratio (width / height).
  final double? aspectRatio;

  /// Unmodified raw JSON payload from UniFi Protect.
  final Map<String, dynamic> rawJson;

  /// All supported detection types (including motion and doorbell ring if applicable).
  Set<ProtectDetectionType> get supportedDetectionTypes {
    final Set<ProtectDetectionType> types = <ProtectDetectionType>{
      ProtectDetectionType.motion
    };
    types.addAll(smartDetectTypes);
    if (isDoorbell) {
      types.add(ProtectDetectionType.ring);
    }
    if (hasPackageCamera) {
      types.add(ProtectDetectionType.package);
    }
    return types;
  }

  /// Finds an active enabled RTSP channel matching the given [quality].
  CameraChannel? getChannelForQuality(StreamQuality quality) {
    for (final CameraChannel channel in channels) {
      if (channel.isRtspEnabled && channel.matchesQuality(quality)) {
        return channel;
      }
    }
    return null;
  }

  /// Returns the package camera channel if enabled.
  CameraChannel? get packageChannel =>
      getChannelForQuality(StreamQuality.package);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      if (marketName != null) 'marketName': marketName,
      if (modelKey != null) 'modelKey': modelKey,
      'isDoorbell': isDoorbell,
      'hasPackageCamera': hasPackageCamera,
      'hasSmartDetect': hasSmartDetect,
      'hasChime': hasChime,
      'hasSpeaker': hasSpeaker,
      'hasMicrophone': hasMicrophone,
      'hasPtz': hasPtz,
      'isOnline': isOnline,
      'smartDetectTypes':
          smartDetectTypes.map((ProtectDetectionType t) => t.name).toList(),
      'channels': channels.map((CameraChannel c) => c.toJson()).toList(),
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
    };
  }
}
