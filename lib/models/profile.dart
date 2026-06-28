enum UserRole { superAdmin, manager, employee }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.manager => 'Manager',
        UserRole.employee => 'Employee',
      };
  String get storageValue => name;
}

/// Parses a stored role string (e.g. from Firestore). Returns `null` when the
/// value is missing or unrecognized — used to mean "no role assigned yet".
UserRole? roleFromString(String? value) {
  if (value == null) return null;
  for (final r in UserRole.values) {
    if (r.name == value) return r;
  }
  return null;
}

class Profile {
  const Profile({required this.name, required this.role});

  final String name;
  final UserRole role;

  Map<String, dynamic> toJson() => {'name': name, 'role': role.name};

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? '',
        role: roleFromString(json['role'] as String?) ?? UserRole.employee,
      );
}
