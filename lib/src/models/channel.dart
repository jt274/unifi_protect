import 'stream_quality.dart';

/// Represents a video stream channel configured on a UniFi Protect camera.
class CameraChannel {
  /// Creates a [CameraChannel] definition.
  const CameraChannel({
    required this.id,
    required this.name,
    required this.isRtspEnabled,
    this.rtspAlias,
    this.width,
    this.height,
    this.fps,
    this.bitrate,
  });

  /// Deserializes a [CameraChannel] from JSON data.
  factory CameraChannel.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final int id = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return CameraChannel(
      id: id,
      name: json['name']?.toString() ?? 'Channel $id',
      isRtspEnabled: json['isRtspEnabled'] == true,
      rtspAlias: json['rtspAlias']?.toString(),
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      fps: json['fps'] is num ? (json['fps'] as num).toInt() : null,
      bitrate: json['bitrate'] is num ? (json['bitrate'] as num).toInt() : null,
    );
  }

  /// Channel ID index (typically 0 for High, 1 for Medium, 2 for Low, 3 for Package).
  final int id;

  /// Display name of the channel (e.g. 'High', 'Low', 'Package Camera').
  final String name;

  /// Whether the RTSP/RTSPS stream is enabled for this channel.
  final bool isRtspEnabled;

  /// Unique 16-character alphanumeric RTSP token/alias if enabled.
  final String? rtspAlias;

  /// Frame width in pixels.
  final int? width;

  /// Frame height in pixels.
  final int? height;

  /// Target frames per second.
  final int? fps;

  /// Bitrate in kbps.
  final int? bitrate;

  /// Computed aspect ratio (width / height), or null if dimensions are unknown.
  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// Whether this channel matches a target [StreamQuality].
  bool matchesQuality(StreamQuality quality) {
    final String lowerName = name.toLowerCase();
    switch (quality) {
      case StreamQuality.package:
        return lowerName.contains('package') || id == 3;
      case StreamQuality.low:
        if (lowerName.contains('package')) {
          return false;
        }
        if (lowerName.contains('low') || id == 2) {
          return true;
        }
        if (width != null && width! <= 720) {
          return true;
        }
        return false;
      case StreamQuality.medium:
        if (lowerName.contains('package')) {
          return false;
        }
        if (lowerName.contains('medium') ||
            lowerName.contains('med') ||
            id == 1) {
          return true;
        }
        if (width != null && width! > 720 && width! <= 1920) {
          return true;
        }
        return false;
      case StreamQuality.high:
        if (lowerName.contains('package')) {
          return false;
        }
        if (lowerName.contains('high') || id == 0) {
          return true;
        }
        if (width != null && width! > 1920) {
          return true;
        }
        return false;
    }
  }

  /// Converts this channel into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'isRtspEnabled': isRtspEnabled,
      if (rtspAlias != null) 'rtspAlias': rtspAlias,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fps != null) 'fps': fps,
      if (bitrate != null) 'bitrate': bitrate,
    };
  }
}
