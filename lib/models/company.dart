import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme_id.dart';

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
    this.themeId = 'classic',
    this.googleReviewUrl,
    this.purchasedSeats = 1,
    this.billingStatus,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
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
  /// Curated theme id: classic | forest | sky.
  final String themeId;
  /// Public Google review / Maps link shown as a QR for customers.
  final String? googleReviewUrl;
  /// Paid location seats for this company (v1 manual / admin).
  final int purchasedSeats;
  /// Optional display: ok | past_due | trialing | canceled
  final String? billingStatus;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? createdByEmail;
  final String? createdByUid;
  final String? rejectionReason;

  bool get isActive => status == CompanyStatus.active;

  static String normalizeCode(String raw) => raw.trim().toUpperCase();

  static int _parseSeats(dynamic raw) {
    if (raw is int && raw >= 0) return raw;
    if (raw is num && raw.toInt() >= 0) return raw.toInt();
    return 1;
  }

  Company copyWith({
    String? name,
    String? companyCode,
    CompanyStatus? status,
    String? logoUrl,
    bool clearLogoUrl = false,
    String? primaryColor,
    bool clearPrimaryColor = false,
    String? themeId,
    String? googleReviewUrl,
    bool clearGoogleReviewUrl = false,
    int? purchasedSeats,
    String? billingStatus,
    bool clearBillingStatus = false,
    String? stripeCustomerId,
    bool clearStripeCustomerId = false,
    String? stripeSubscriptionId,
    bool clearStripeSubscriptionId = false,
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
        logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
        primaryColor:
            clearPrimaryColor ? null : (primaryColor ?? this.primaryColor),
        themeId: themeId ?? this.themeId,
        googleReviewUrl: clearGoogleReviewUrl
            ? null
            : (googleReviewUrl ?? this.googleReviewUrl),
        purchasedSeats: purchasedSeats ?? this.purchasedSeats,
        billingStatus: clearBillingStatus
            ? null
            : (billingStatus ?? this.billingStatus),
        stripeCustomerId: clearStripeCustomerId
            ? null
            : (stripeCustomerId ?? this.stripeCustomerId),
        stripeSubscriptionId: clearStripeSubscriptionId
            ? null
            : (stripeSubscriptionId ?? this.stripeSubscriptionId),
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
        'themeId': themeId,
        'purchasedSeats': purchasedSeats,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (primaryColor != null) 'primaryColor': primaryColor,
        if (googleReviewUrl != null) 'googleReviewUrl': googleReviewUrl,
        if (billingStatus != null) 'billingStatus': billingStatus,
        if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
        if (stripeSubscriptionId != null)
          'stripeSubscriptionId': stripeSubscriptionId,
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
    final billing = (data['billingStatus'] as String?)?.trim();
    final stripeCustomer = (data['stripeCustomerId'] as String?)?.trim();
    final stripeSub = (data['stripeSubscriptionId'] as String?)?.trim();
    return Company(
      id: id,
      name: data['name'] as String? ?? id,
      companyCode: data['companyCode'] as String? ?? '',
      status: CompanyStatusLabel.fromString(data['status'] as String?) ??
          CompanyStatus.pending,
      logoUrl: data['logoUrl'] as String?,
      primaryColor: data['primaryColor'] as String?,
      themeId: AppThemeIdX.parse(data['themeId'] as String?).firestoreValue,
      googleReviewUrl: (review == null || review.isEmpty) ? null : review,
      purchasedSeats: _parseSeats(data['purchasedSeats']),
      billingStatus: (billing == null || billing.isEmpty) ? null : billing,
      stripeCustomerId:
          (stripeCustomer == null || stripeCustomer.isEmpty) ? null : stripeCustomer,
      stripeSubscriptionId:
          (stripeSub == null || stripeSub.isEmpty) ? null : stripeSub,
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
