import 'package:cloud_firestore/cloud_firestore.dart';

class RequestPreset {
  const RequestPreset({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.createdAt,
    this.createdByUid,
  });

  final String id;
  final String label;
  final int sortOrder;
  final DateTime? createdAt;
  final String? createdByUid;

  Map<String, dynamic> toMap() => {
        'label': label.trim(),
        'sortOrder': sortOrder,
        if (createdByUid != null) 'createdByUid': createdByUid,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory RequestPreset.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    return RequestPreset(
      id: id,
      label: (data['label'] as String? ?? '').trim(),
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      createdByUid: data['createdByUid'] as String?,
    );
  }

  factory RequestPreset.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      RequestPreset.fromMap(doc.id, doc.data() ?? {});
}
