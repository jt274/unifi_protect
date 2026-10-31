/// Metadata about the UniFi Protect application and controller.
class ProtectMetaInfo {
  const ProtectMetaInfo({
    required this.version,
    this.build,
    this.releaseChannel,
    this.controllerVersion,
    this.rawJson = const <String, dynamic>{},
  });

  factory ProtectMetaInfo.fromJson(Map<String, dynamic> json) {
    return ProtectMetaInfo(
      version: json['version']?.toString() ?? '',
      build: json['build']?.toString(),
      releaseChannel: json['releaseChannel']?.toString(),
      controllerVersion: json['controllerVersion']?.toString(),
      rawJson: json,
    );
  }

  final String version;
  final String? build;
  final String? releaseChannel;
  final String? controllerVersion;
  final Map<String, dynamic> rawJson;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      if (build != null) 'build': build,
      if (releaseChannel != null) 'releaseChannel': releaseChannel,
      if (controllerVersion != null) 'controllerVersion': controllerVersion,
    };
  }
}
