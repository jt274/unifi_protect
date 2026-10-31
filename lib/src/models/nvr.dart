/// Represents a UniFi Protect Network Video Recorder (NVR) host console.
class ProtectNvr {
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

  final String id;
  final String name;
  final String version;
  final String? firmwareVersion;
  final int? uptimeMs;
  final int? storageTotalBytes;
  final int? storageUsedBytes;
  final int? storageAvailableBytes;
  final bool isRecording;
  final int cameraCount;
  final Map<String, dynamic> rawJson;

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
