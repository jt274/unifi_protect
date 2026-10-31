/// Represents an individual slot in a multi-camera live view layout.
class LiveviewSlot {
  const LiveviewSlot({
    required this.cameraIds,
    this.cycleMode = 'none',
    this.cycleInterval = 10,
  });

  factory LiveviewSlot.fromJson(Map<String, dynamic> json) {
    final dynamic rawCameras = json['cameras'] ?? json['cameraIds'];
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

    return LiveviewSlot(
      cameraIds: cameraIds,
      cycleMode: json['cycleMode']?.toString() ?? 'none',
      cycleInterval: (json['cycleInterval'] as num?)?.toInt() ?? 10,
    );
  }

  /// Cameras assigned to this slot.
  final List<String> cameraIds;

  /// Cycle mode for multiple cameras in the slot (e.g. 'none', 'motion', 'interval').
  final String cycleMode;

  /// Time in seconds before cycling to the next camera if in interval mode.
  final int cycleInterval;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cameras': cameraIds,
      'cycleMode': cycleMode,
      'cycleInterval': cycleInterval,
    };
  }
}

/// Represents a UniFi Protect multi-camera live view grid layout.
class ProtectLiveview {
  const ProtectLiveview({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.isGlobal = false,
    this.slots = const <LiveviewSlot>[],
    this.rawJson = const <String, dynamic>{},
  });

  factory ProtectLiveview.fromJson(Map<String, dynamic> json) {
    final dynamic rawSlots = json['slots'];
    final List<LiveviewSlot> slots = <LiveviewSlot>[];
    if (rawSlots is List<dynamic>) {
      for (final dynamic raw in rawSlots) {
        if (raw is Map<String, dynamic>) {
          slots.add(LiveviewSlot.fromJson(raw));
        }
      }
    }

    return ProtectLiveview(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Live View',
      isDefault: json['isDefault'] == true,
      isGlobal: json['isGlobal'] == true,
      slots: slots,
      rawJson: json,
    );
  }

  final String id;
  final String name;
  final bool isDefault;
  final bool isGlobal;
  final List<LiveviewSlot> slots;
  final Map<String, dynamic> rawJson;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'isDefault': isDefault,
      'isGlobal': isGlobal,
      'slots': slots.map((LiveviewSlot s) => s.toJson()).toList(),
    };
  }
}
