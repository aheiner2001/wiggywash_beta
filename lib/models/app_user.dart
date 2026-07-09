import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile.dart';

/// The signed-in account, mirrored from `users/{uid}` in Firestore. A user with
/// a `null` [role] is signed in but not yet provisioned — they must be approved
/// by a manager (their email is on a location allowlist) or enter a master code.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role,
    this.companyId,
    this.locationId,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole? role;
  final String? companyId;
  final String? locationId;
  final DateTime? createdAt;

  /// A friendly name for scorecards/dashboards: the provider display name, or
  /// the email's local part as a fallback.
  String get name {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  bool get isProvisioned => role != null;

  AppUser copyWith({
    UserRole? role,
    String? companyId,
    String? locationId,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        role: role ?? this.role,
        companyId: companyId ?? this.companyId,
        locationId: locationId ?? this.locationId,
        createdAt: createdAt,
      );

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String? ?? '').toLowerCase(),
      displayName: data['displayName'] as String? ?? '',
      role: roleFromString(data['role'] as String?),
      companyId: data['companyId'] as String?,
      locationId: data['locationId'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
