/// Represents a UniFi Protect multi-sensor device.
class ProtectSensor {
  /// Creates a [ProtectSensor] instance.
  const ProtectSensor({
    required this.id,
    required this.name,
    required this.type,
    this.isOnline = true,
    this.batteryPercentage,
    this.isMotionDetected = false,
    this.isOpen = false,
    this.temperature,
    this.humidity,
    this.lightLevel,
    this.isAlarmDetected = false,
    this.rawJson = const <String, dynamic>{},
  });

  /// Deserializes a [ProtectSensor] from JSON returned by the Protect API.
  factory ProtectSensor.fromJson(Map<String, dynamic> json) {
    final String? stateStr = json['state']?.toString().toUpperCase();
    final bool isOnline = stateStr == null || stateStr == 'CONNECTED';

    final Map<String, dynamic> batteryStatus =
        json['batteryStatus'] is Map<String, dynamic>
            ? json['batteryStatus'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final int? battery = (batteryStatus['percentage'] as num?)?.toInt() ??
        (json['batteryPercentage'] as num?)?.toInt();

    final Map<String, dynamic> stats = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final dynamic tempObj = stats['temperature'];
    final dynamic humObj = stats['humidity'];
    final dynamic lightObj = stats['light'];

    final double? tempVal = (tempObj is Map<String, dynamic>
            ? (tempObj['value'] as num?)?.toDouble()
            : null) ??
        (json['temperature'] as num?)?.toDouble();
    final double? humVal = (humObj is Map<String, dynamic>
            ? (humObj['value'] as num?)?.toDouble()
            : null) ??
        (json['humidity'] as num?)?.toDouble();
    final double? lightVal = (lightObj is Map<String, dynamic>
            ? (lightObj['value'] as num?)?.toDouble()
            : null) ??
        (json['light'] as num?)?.toDouble();

    return ProtectSensor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UniFi Sensor',
      type: json['type']?.toString() ?? 'UP-Sense',
      isOnline: isOnline,
      batteryPercentage: battery,
      isMotionDetected: json['isMotionDetected'] == true,
      isOpen: json['isOpen'] == true || json['openStatus'] == 'open',
      temperature: tempVal,
      humidity: humVal,
      lightLevel: lightVal,
      isAlarmDetected: json['isAlarmDetected'] == true,
      rawJson: json,
    );
  }

  /// Unique identifier of the sensor.
  final String id;

  /// User-configured display name.
  final String name;

  /// Hardware device model type.
  final String type;

  /// Whether the sensor is currently connected and online.
  final bool isOnline;

  /// Remaining battery percentage (0-100), if battery-operated.
  final int? batteryPercentage;

  /// Whether motion is currently detected by the sensor.
  final bool isMotionDetected;

  /// Whether the door/window contact sensor is currently open.
  final bool isOpen;

  /// Ambient temperature reading in degrees Celsius.
  final double? temperature;

  /// Relative humidity percentage reading (0-100).
  final double? humidity;

  /// Ambient light level reading in lux.
  final double? lightLevel;

  /// Whether an audio smoke/CO alarm was detected.
  final bool isAlarmDetected;

  /// Raw JSON payload from the API.
  final Map<String, dynamic> rawJson;

  /// Converts this sensor instance into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'isOnline': isOnline,
      if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
      'isMotionDetected': isMotionDetected,
      'isOpen': isOpen,
      if (temperature != null) 'temperature': temperature,
      if (humidity != null) 'humidity': humidity,
      if (lightLevel != null) 'lightLevel': lightLevel,
      'isAlarmDetected': isAlarmDetected,
    };
  }
}
