import 'package:cloud_firestore/cloud_firestore.dart';

import 'location_access.dart';

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
    this.accessStatus = LocationAccessStatus.active,
    this.trialEndsAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String city;

  /// The code employees type to reach this site's roster. Set by the manager.
  final String siteCode;
  final bool active;
  final LocationAccessStatus accessStatus;
  final DateTime? trialEndsAt;
  final DateTime? createdAt;

  String get displayName => city.isEmpty ? name : '$name — $city';

  Map<String, dynamic> toMap() => {
        'name': name,
        'city': city,
        'siteCode': siteCode,
        'active': active,
        'accessStatus': accessStatus.firestoreValue,
        if (trialEndsAt != null)
          'trialEndsAt': Timestamp.fromDate(trialEndsAt!),
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Location.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    final trialTs = data['trialEndsAt'];
    return Location(
      id: id,
      name: data['name'] as String? ?? id,
      city: data['city'] as String? ?? '',
      siteCode: data['siteCode'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      accessStatus: LocationAccessStatusX.parse(data['accessStatus'] as String?),
      trialEndsAt: trialTs is Timestamp ? trialTs.toDate() : null,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  factory Location.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Location.fromMap(doc.id, doc.data() ?? {});
}
