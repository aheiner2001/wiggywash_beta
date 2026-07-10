enum LocationAccessStatus { active, trial, readOnly }

extension LocationAccessStatusX on LocationAccessStatus {
  String get firestoreValue => switch (this) {
        LocationAccessStatus.active => 'active',
        LocationAccessStatus.trial => 'trial',
        LocationAccessStatus.readOnly => 'read_only',
      };

  static LocationAccessStatus parse(String? raw) {
    switch (raw) {
      case 'trial':
        return LocationAccessStatus.trial;
      case 'read_only':
        return LocationAccessStatus.readOnly;
      case 'active':
      default:
        return LocationAccessStatus.active;
    }
  }
}
