class ManagerInvite {
  const ManagerInvite({
    required this.id,
    required this.companyId,
    required this.email,
    this.displayName,
    required this.invitedByUid,
    required this.invitedByEmail,
    this.createdAt,
    this.claimedUid,
  });

  final String id;
  final String companyId;
  final String email;
  final String? displayName;
  final String invitedByUid;
  final String invitedByEmail;
  final DateTime? createdAt;
  final String? claimedUid;

  bool get isClaimed => claimedUid != null && claimedUid!.isNotEmpty;

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  Map<String, dynamic> toMap() => {
        'email': email,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
        'invitedByUid': invitedByUid,
        'invitedByEmail': invitedByEmail,
        if (claimedUid != null) 'claimedUid': claimedUid,
      };

  factory ManagerInvite.fromMap(
    String id,
    Map<String, dynamic> data, {
    required String companyId,
  }) {
    return ManagerInvite(
      id: id,
      companyId: companyId,
      email: normalizeEmail(data['email'] as String? ?? ''),
      displayName: data['displayName'] as String?,
      invitedByUid: data['invitedByUid'] as String? ?? '',
      invitedByEmail: normalizeEmail(data['invitedByEmail'] as String? ?? ''),
      claimedUid: data['claimedUid'] as String?,
    );
  }
}
