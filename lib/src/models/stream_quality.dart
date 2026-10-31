/// Quality channel presets supported by UniFi Protect RTSP / RTSPS streams.
enum StreamQuality {
  /// Low resolution preview stream (typically 640x360).
  low('Low (640×360)'),

  /// Medium resolution balanced stream (typically 720p or 1080p).
  medium('Medium (720p/1080p)'),

  /// Highest native camera resolution stream (up to 4K).
  high('High (4K / Full Resolution)'),

  /// Dedicated secondary package camera stream (e.g. G4 Doorbell Pro).
  package('Package Camera (Doorbell Pro)');

  const StreamQuality(this.displayName);

  /// User-friendly label describing the resolution.
  final String displayName;

  /// Parses a string into a [StreamQuality] enum value.
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
