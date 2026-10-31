/// Represents a UniFi Protect Network Video Recorder (NVR) host console.
class ProtectNvr {
  /// Creates a [ProtectNvr] console instance.
  const ProtectNvr({
    required this.id,
    required this.name,
    required this.version,
    this.firmwareVersion,
    this.uptimeMs,
    this.storageTotalBytes,
    this.storageUsedBytes,
    this.storageAvailableBytes,
    this.isRecording = true,
    this.cameraCount = 0,
    this.rawJson = const <String, dynamic>{},
  });

  /// Deserializes a [ProtectNvr] from JSON returned by the Protect API.
  factory ProtectNvr.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> storageInfo =
        json['storageInfo'] is Map<String, dynamic>
            ? json['storageInfo'] as Map<String, dynamic>
            : const <String, dynamic>{};

    return ProtectNvr(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'UniFi NVR',
      version: json['version']?.toString() ?? '',
      firmwareVersion: json['firmwareVersion']?.toString(),
      uptimeMs: (json['upSince'] as num?)?.toInt() ??
          (json['uptime'] as num?)?.toInt(),
      storageTotalBytes: (storageInfo['totalSize'] as num?)?.toInt(),
      storageUsedBytes: (storageInfo['usedSize'] as num?)?.toInt(),
      storageAvailableBytes: (storageInfo['availableSize'] as num?)?.toInt(),
      isRecording: json['isRecording'] != false,
      cameraCount: (json['cameraCount'] as num?)?.toInt() ?? 0,
      rawJson: json,
    );
  }

  /// Unique identifier of the NVR.
  final String id;

  /// System hostname or friendly name.
  final String name;

  /// UniFi Protect application version.
  final String version;

  /// UniFi OS firmware version, if available.
  final String? firmwareVersion;

  /// Uptime in milliseconds.
  final int? uptimeMs;

  /// Total storage capacity across disks in bytes.
  final int? storageTotalBytes;

  /// Used storage space in bytes.
  final int? storageUsedBytes;

  /// Free storage space available for recording in bytes.
  final int? storageAvailableBytes;

  /// Whether video recording is globally active.
  final bool isRecording;

  /// Total count of adopted cameras.
  final int cameraCount;

  /// Raw JSON payload from the API.
  final Map<String, dynamic> rawJson;

  /// Converts this NVR instance into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'version': version,
      if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
      if (uptimeMs != null) 'uptimeMs': uptimeMs,
      if (storageTotalBytes != null) 'storageTotalBytes': storageTotalBytes,
      if (storageUsedBytes != null) 'storageUsedBytes': storageUsedBytes,
      if (storageAvailableBytes != null)
        'storageAvailableBytes': storageAvailableBytes,
      'isRecording': isRecording,
      'cameraCount': cameraCount,
    };
  }
}
