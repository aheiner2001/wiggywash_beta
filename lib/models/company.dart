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
    this.createdAt,
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String name;
  final String companyCode;
  final CompanyStatus status;
  final String? logoUrl;
  final String? primaryColor;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  bool get isActive => status == CompanyStatus.active;

  static String normalizeCode(String raw) => raw.trim().toUpperCase();

  Map<String, dynamic> toMap() => {
        'name': name,
        'companyCode': normalizeCode(companyCode),
        'status': status.firestoreValue,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (primaryColor != null) 'primaryColor': primaryColor,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
        if (approvedBy != null) 'approvedBy': approvedBy,
      };

  factory Company.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    final ats = data['approvedAt'];
    return Company(
      id: id,
      name: data['name'] as String? ?? id,
      companyCode: data['companyCode'] as String? ?? '',
      status: CompanyStatusLabel.fromString(data['status'] as String?) ??
          CompanyStatus.pending,
      logoUrl: data['logoUrl'] as String?,
      primaryColor: data['primaryColor'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      approvedAt: ats is Timestamp ? ats.toDate() : null,
      approvedBy: data['approvedBy'] as String?,
    );
  }

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Company.fromMap(doc.id, doc.data() ?? {});
}
