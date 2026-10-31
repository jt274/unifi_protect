/// Represents a UniFi Protect ViewPort HDMI display device.
class ProtectViewer {
  /// Creates a [ProtectViewer] instance.
  const ProtectViewer({
    required this.id,
    required this.name,
    required this.type,
    this.isOnline = true,
    this.liveviewId,
    this.rawJson = const <String, dynamic>{},
  });

  /// Deserializes a [ProtectViewer] from JSON returned by the Protect API.
  factory ProtectViewer.fromJson(Map<String, dynamic> json) {
    final String? stateStr = json['state']?.toString().toUpperCase();
    final bool isOnline = stateStr == null || stateStr == 'CONNECTED';

    return ProtectViewer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UniFi ViewPort',
      type: json['type']?.toString() ?? 'UVP-ViewPort',
      isOnline: isOnline,
      liveviewId:
          json['liveview']?.toString() ?? json['liveviewId']?.toString(),
      rawJson: json,
    );
  }

  /// Unique identifier of the ViewPort device.
  final String id;

  /// User-configured display name.
  final String name;

  /// Hardware device model type.
  final String type;

  /// Whether the ViewPort is currently connected and online.
  final bool isOnline;

  /// Currently active live view layout assigned to this display.
  final String? liveviewId;

  /// Raw JSON payload from the API.
  final Map<String, dynamic> rawJson;

  /// Converts this ViewPort instance into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'isOnline': isOnline,
      if (liveviewId != null) 'liveviewId': liveviewId,
    };
  }
}
