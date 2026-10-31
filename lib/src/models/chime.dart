/// Represents a UniFi Protect smart chime.
class ProtectChime {
  /// Creates a [ProtectChime] instance.
  const ProtectChime({
    required this.id,
    required this.name,
    required this.type,
    this.isOnline = true,
    this.volume = 80,
    this.cameraIds = const <String>[],
    this.ringSettings = const <String, dynamic>{},
    this.rawJson = const <String, dynamic>{},
  });

  /// Deserializes a [ProtectChime] from JSON returned by the Protect API.
  factory ProtectChime.fromJson(Map<String, dynamic> json) {
    final String? stateStr = json['state']?.toString().toUpperCase();
    final bool isOnline = stateStr == null || stateStr == 'CONNECTED';

    final dynamic rawCameras = json['cameraIds'] ?? json['cameras'];
    final List<String> cameraIds = <String>[];
    if (rawCameras is List<dynamic>) {
      for (final dynamic item in rawCameras) {
        if (item is String) {
          cameraIds.add(item);
        } else if (item is Map<String, dynamic> && item['id'] != null) {
          cameraIds.add(item['id'].toString());
        }
      }
    }

    final Map<String, dynamic> ring =
        json['ringSettings'] is Map<String, dynamic>
            ? json['ringSettings'] as Map<String, dynamic>
            : const <String, dynamic>{};

    final int vol = (json['volume'] as num?)?.toInt() ??
        (ring['volume'] as num?)?.toInt() ??
        80;

    return ProtectChime(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UniFi Chime',
      type: json['type']?.toString() ?? 'UP-Chime',
      isOnline: isOnline,
      volume: vol,
      cameraIds: cameraIds,
      ringSettings: ring,
      rawJson: json,
    );
  }

  /// Unique identifier of the chime.
  final String id;

  /// User-configured display name.
  final String name;

  /// Hardware device type or model.
  final String type;

  /// Whether the chime is currently connected and online.
  final bool isOnline;

  /// Audio volume level percentage (0-100).
  final int volume;

  /// List of camera IDs paired to ring this chime.
  final List<String> cameraIds;

  /// Ring and buzzer configuration parameters.
  final Map<String, dynamic> ringSettings;

  /// Raw JSON payload from the API.
  final Map<String, dynamic> rawJson;

  /// Converts this chime instance into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'isOnline': isOnline,
      'volume': volume,
      'cameraIds': cameraIds,
      'ringSettings': ringSettings,
    };
  }
}
