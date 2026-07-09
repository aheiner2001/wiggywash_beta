enum UserRole { platformAdmin, companyManager, employee }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.platformAdmin => 'Platform Admin',
        UserRole.companyManager => 'Manager',
        UserRole.employee => 'Employee',
      };

  /// Firestore value written to users/{uid}.role
  String get firestoreValue => name;
}

/// Parses a stored role string (e.g. from Firestore). Returns `null` when the
/// value is missing or unrecognized — used to mean "no role assigned yet".
UserRole? roleFromString(String? value) {
  if (value == null) return null;
  // Backward compatibility with pre-SaaS role names.
  final normalized = switch (value) {
    'superAdmin' => 'platformAdmin',
    'manager' => 'companyManager',
    _ => value,
  };
  for (final r in UserRole.values) {
    if (r.name == normalized) return r;
  }
  return null;
}

class Profile {
  const Profile({required this.name, required this.role});

  final String name;
  final UserRole role;

  Map<String, dynamic> toJson() => {'name': name, 'role': role.firestoreValue};

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? '',
        role: roleFromString(json['role'] as String?) ?? UserRole.employee,
      );
}
