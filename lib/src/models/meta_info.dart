/// Metadata about the UniFi Protect application and controller.
class ProtectMetaInfo {
  /// Creates a [ProtectMetaInfo] instance.
  const ProtectMetaInfo({
    required this.version,
    this.build,
    this.releaseChannel,
    this.controllerVersion,
    this.rawJson = const <String, dynamic>{},
  });

  /// Deserializes [ProtectMetaInfo] from JSON returned by the Protect API.
  factory ProtectMetaInfo.fromJson(Map<String, dynamic> json) {
    return ProtectMetaInfo(
      version: json['version']?.toString() ?? '',
      build: json['build']?.toString(),
      releaseChannel: json['releaseChannel']?.toString(),
      controllerVersion: json['controllerVersion']?.toString(),
      rawJson: json,
    );
  }

  /// The Protect application version string.
  final String version;

  /// The application build identifier.
  final String? build;

  /// The release channel (e.g. 'release', 'beta', 'ea').
  final String? releaseChannel;

  /// The underlying UniFi OS controller version.
  final String? controllerVersion;

  /// Raw JSON payload from the API.
  final Map<String, dynamic> rawJson;

  /// Converts this metadata into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      if (build != null) 'build': build,
      if (releaseChannel != null) 'releaseChannel': releaseChannel,
      if (controllerVersion != null) 'controllerVersion': controllerVersion,
    };
  }
}
