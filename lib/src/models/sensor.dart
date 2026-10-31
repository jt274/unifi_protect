/// Represents a UniFi Protect multi-sensor device.
class ProtectSensor {
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

  final String id;
  final String name;
  final String type;
  final bool isOnline;
  final int? batteryPercentage;
  final bool isMotionDetected;
  final bool isOpen;
  final double? temperature;
  final double? humidity;
  final double? lightLevel;
  final bool isAlarmDetected;
  final Map<String, dynamic> rawJson;

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
