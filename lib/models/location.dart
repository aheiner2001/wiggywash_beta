import 'package:cloud_firestore/cloud_firestore.dart';

/// A car-wash site. Everything operational (submissions, roster, prices,
/// settings) lives in subcollections under `locations/{id}` so the app scales
/// from one pilot site to many without reshaping data.
class Location {
  const Location({
    required this.id,
    required this.name,
    this.city = '',
    this.siteCode = '',
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String city;

  /// The code employees type to reach this site's roster. Set by the manager.
  final String siteCode;
  final bool active;
  final DateTime? createdAt;

  String get displayName => city.isEmpty ? name : '$name — $city';

  Map<String, dynamic> toMap() => {
        'name': name,
        'city': city,
        'siteCode': siteCode,
        'active': active,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Location.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    return Location(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      city: data['city'] as String? ?? '',
      siteCode: data['siteCode'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
