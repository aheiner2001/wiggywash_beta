enum LocationAccessStatus { active, trial, comp, readOnly }

extension LocationAccessStatusX on LocationAccessStatus {
  String get firestoreValue => switch (this) {
        LocationAccessStatus.active => 'active',
        LocationAccessStatus.trial => 'trial',
        LocationAccessStatus.comp => 'comp',
        LocationAccessStatus.readOnly => 'read_only',
      };

  String get label => switch (this) {
        LocationAccessStatus.active => 'Active',
        LocationAccessStatus.trial => 'Trial',
        LocationAccessStatus.comp => 'Comp',
        LocationAccessStatus.readOnly => 'Read-only',
      };

  static LocationAccessStatus parse(String? raw) {
    switch (raw) {
      case 'trial':
        return LocationAccessStatus.trial;
      case 'comp':
        return LocationAccessStatus.comp;
      case 'read_only':
        return LocationAccessStatus.readOnly;
      case 'active':
      default:
        return LocationAccessStatus.active;
    }
  }
}
