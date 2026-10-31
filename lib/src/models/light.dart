/// Represents a UniFi Protect smart floodlight.
class ProtectLight {
  /// Creates a [ProtectLight] instance.
  const ProtectLight({
    required this.id,
    required this.name,
    required this.type,
    this.isOnline = true,
    this.isLedOn = false,
    this.brightness = 100,
    this.isPirMotionDetected = false,
    this.rawJson = const <String, dynamic>{},
  });

  /// Deserializes a [ProtectLight] from JSON returned by the Protect API.
  factory ProtectLight.fromJson(Map<String, dynamic> json) {
    final String? stateStr = json['state']?.toString().toUpperCase();
    final bool isOnline = stateStr == null || stateStr == 'CONNECTED';
    final Map<String, dynamic> lightSettings =
        json['lightDeviceSettings'] is Map<String, dynamic>
            ? json['lightDeviceSettings'] as Map<String, dynamic>
            : const <String, dynamic>{};

    return ProtectLight(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UniFi Light',
      type: json['type']?.toString() ?? 'UP-FloodLight',
      isOnline: isOnline,
      isLedOn: json['isLedOn'] == true,
      brightness: (lightSettings['ledLevel'] as num?)?.toInt() ?? 100,
      isPirMotionDetected: json['isPirMotionDetected'] == true,
      rawJson: json,
    );
  }

  /// Unique identifier of the floodlight.
  final String id;

  /// User-configured display name.
  final String name;

  /// Hardware device model type.
  final String type;

  /// Whether the light is connected and online.
  final bool isOnline;

  /// Whether the floodlight LED is currently turned on.
  final bool isLedOn;

  /// LED brightness percentage (1-100).
  final int brightness;

  /// Whether PIR motion is currently detected by the light's motion sensor.
  final bool isPirMotionDetected;

  /// Raw JSON payload from the API.
  final Map<String, dynamic> rawJson;

  /// Converts this floodlight instance into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'isOnline': isOnline,
      'isLedOn': isLedOn,
      'brightness': brightness,
      'isPirMotionDetected': isPirMotionDetected,
    };
  }
}
