import 'package:cloud_firestore/cloud_firestore.dart';

enum CompanyStatus { pending, active, suspended }

extension CompanyStatusLabel on CompanyStatus {
  String get firestoreValue => name;

  static CompanyStatus? fromString(String? v) {
    if (v == null) return null;
    for (final s in CompanyStatus.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.companyCode,
    this.status = CompanyStatus.pending,
    this.logoUrl,
    this.primaryColor,
    this.googleReviewUrl,
    this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.createdByEmail,
    this.createdByUid,
    this.rejectionReason,
  });

  final String id;
  final String name;
  final String companyCode;
  final CompanyStatus status;
  final String? logoUrl;
  final String? primaryColor;
  /// Public Google review / Maps link shown as a QR for customers.
  final String? googleReviewUrl;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? createdByEmail;
  final String? createdByUid;
  final String? rejectionReason;

  bool get isActive => status == CompanyStatus.active;

  static String normalizeCode(String raw) => raw.trim().toUpperCase();

  Company copyWith({
    String? name,
    String? companyCode,
    CompanyStatus? status,
    String? logoUrl,
    String? primaryColor,
    bool clearPrimaryColor = false,
    String? googleReviewUrl,
    bool clearGoogleReviewUrl = false,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? createdByEmail,
    String? createdByUid,
    String? rejectionReason,
  }) =>
      Company(
        id: id,
        name: name ?? this.name,
        companyCode: companyCode ?? this.companyCode,
        status: status ?? this.status,
        logoUrl: logoUrl ?? this.logoUrl,
        primaryColor:
            clearPrimaryColor ? null : (primaryColor ?? this.primaryColor),
        googleReviewUrl: clearGoogleReviewUrl
            ? null
            : (googleReviewUrl ?? this.googleReviewUrl),
        createdAt: createdAt ?? this.createdAt,
        approvedAt: approvedAt ?? this.approvedAt,
        approvedBy: approvedBy ?? this.approvedBy,
        createdByEmail: createdByEmail ?? this.createdByEmail,
        createdByUid: createdByUid ?? this.createdByUid,
        rejectionReason: rejectionReason ?? this.rejectionReason,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'companyCode': normalizeCode(companyCode),
        'status': status.firestoreValue,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (primaryColor != null) 'primaryColor': primaryColor,
        if (googleReviewUrl != null) 'googleReviewUrl': googleReviewUrl,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (createdByEmail != null) 'createdByEmail': createdByEmail,
        if (createdByUid != null) 'createdByUid': createdByUid,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

  factory Company.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    final ats = data['approvedAt'];
    final review = (data['googleReviewUrl'] as String?)?.trim();
    return Company(
      id: id,
      name: data['name'] as String? ?? id,
      companyCode: data['companyCode'] as String? ?? '',
      status: CompanyStatusLabel.fromString(data['status'] as String?) ??
          CompanyStatus.pending,
      logoUrl: data['logoUrl'] as String?,
      primaryColor: data['primaryColor'] as String?,
      googleReviewUrl: (review == null || review.isEmpty) ? null : review,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      approvedAt: ats is Timestamp ? ats.toDate() : null,
      approvedBy: data['approvedBy'] as String?,
      createdByEmail: data['createdByEmail'] as String?,
      createdByUid: data['createdByUid'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Company.fromMap(doc.id, doc.data() ?? {});
}
