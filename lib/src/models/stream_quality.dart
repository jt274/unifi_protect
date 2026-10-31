/// Quality channel presets supported by UniFi Protect RTSP / RTSPS streams.
enum StreamQuality {
  low('Low (640×360)'),
  medium('Medium (720p/1080p)'),
  high('High (4K / Full Resolution)'),
  package('Package Camera (Doorbell Pro)');

  const StreamQuality(this.displayName);
  final String displayName;

  static StreamQuality fromString(String value) {
    final String normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'high':
        return StreamQuality.high;
      case 'medium':
      case 'med':
        return StreamQuality.medium;
      case 'package':
        return StreamQuality.package;
      case 'low':
      default:
        return StreamQuality.low;
    }
  }
}
