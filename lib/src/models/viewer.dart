/// Represents a UniFi Protect ViewPort HDMI display device.
class ProtectViewer {
  const ProtectViewer({
    required this.id,
    required this.name,
    required this.type,
    this.isOnline = true,
    this.liveviewId,
    this.rawJson = const <String, dynamic>{},
  });

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

  final String id;
  final String name;
  final String type;
  final bool isOnline;
  final String? liveviewId;
  final Map<String, dynamic> rawJson;

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
