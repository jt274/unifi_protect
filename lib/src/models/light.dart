/// Represents a UniFi Protect smart floodlight.
class ProtectLight {
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

  final String id;
  final String name;
  final String type;
  final bool isOnline;
  final bool isLedOn;
  final int brightness;
  final bool isPirMotionDetected;
  final Map<String, dynamic> rawJson;

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
