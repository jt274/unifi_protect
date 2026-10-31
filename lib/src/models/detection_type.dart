/// Supported smart and motion detection types from UniFi Protect.
enum ProtectDetectionType {
  /// General video motion detection.
  motion,

  /// Person smart detection.
  person,

  /// Vehicle smart detection.
  vehicle,

  /// Package smart detection.
  package,

  /// Animal smart detection.
  animal,

  /// Doorbell physical ring event.
  ring,

  /// Smoke detector audio alarm detection.
  smoke,

  /// Carbon monoxide detector audio alarm detection.
  cmonoxide,

  /// Siren audio alarm detection.
  siren;

  /// User-friendly display name for this detection type.
  String get displayName {
    switch (this) {
      case ProtectDetectionType.motion:
        return 'Motion';
      case ProtectDetectionType.person:
        return 'Person';
      case ProtectDetectionType.vehicle:
        return 'Vehicle';
      case ProtectDetectionType.package:
        return 'Package';
      case ProtectDetectionType.animal:
        return 'Animal';
      case ProtectDetectionType.ring:
        return 'Doorbell Ring';
      case ProtectDetectionType.smoke:
        return 'Smoke Alarm';
      case ProtectDetectionType.cmonoxide:
        return 'Carbon Monoxide';
      case ProtectDetectionType.siren:
        return 'Siren Alarm';
    }
  }

  /// Parses a string representation into a [ProtectDetectionType].
  static ProtectDetectionType fromString(String value) {
    final String normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'person':
      case 'smartdetectzone.person':
        return ProtectDetectionType.person;
      case 'vehicle':
      case 'car':
      case 'smartdetectzone.vehicle':
        return ProtectDetectionType.vehicle;
      case 'package':
      case 'smartdetectzone.package':
        return ProtectDetectionType.package;
      case 'animal':
      case 'pet':
      case 'smartdetectzone.animal':
        return ProtectDetectionType.animal;
      case 'ring':
      case 'doorbell':
        return ProtectDetectionType.ring;
      case 'smoke':
      case 'smokealarm':
        return ProtectDetectionType.smoke;
      case 'co':
      case 'cmonoxide':
      case 'carbonmonoxide':
        return ProtectDetectionType.cmonoxide;
      case 'siren':
        return ProtectDetectionType.siren;
      case 'motion':
      default:
        return ProtectDetectionType.motion;
    }
  }
}
