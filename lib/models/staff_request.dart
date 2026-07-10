import 'package:cloud_firestore/cloud_firestore.dart';

enum StaffRequestStatus { pending, accepted, completed, dismissed }

extension StaffRequestStatusX on StaffRequestStatus {
  String get firestoreValue => name;

  String get employeeLabel => switch (this) {
        StaffRequestStatus.pending => 'Sent',
        StaffRequestStatus.accepted => 'Accepted',
        StaffRequestStatus.completed => 'Done',
        StaffRequestStatus.dismissed => 'Dismissed',
      };

  static StaffRequestStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return StaffRequestStatus.pending;
    for (final s in StaffRequestStatus.values) {
      if (s.name == raw) return s;
    }
    return StaffRequestStatus.pending;
  }
}

class StaffRequest {
  const StaffRequest({
    required this.id,
    required this.text,
    required this.employeeName,
    this.employeeProfileKey,
    this.presetId,
    this.status = StaffRequestStatus.pending,
    this.createdAt,
    this.acceptedAt,
    this.acceptedByUid,
    this.completedAt,
    this.completedByUid,
    this.dismissedAt,
  });

  final String id;
  final String text;
  final String employeeName;
  final String? employeeProfileKey;
  final String? presetId;
  final StaffRequestStatus status;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final String? acceptedByUid;
  final DateTime? completedAt;
  final String? completedByUid;
  final DateTime? dismissedAt;

  StaffRequest copyWith({
    StaffRequestStatus? status,
    DateTime? acceptedAt,
    String? acceptedByUid,
    DateTime? completedAt,
    String? completedByUid,
    DateTime? dismissedAt,
  }) =>
      StaffRequest(
        id: id,
        text: text,
        employeeName: employeeName,
        employeeProfileKey: employeeProfileKey,
        presetId: presetId,
        status: status ?? this.status,
        createdAt: createdAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        acceptedByUid: acceptedByUid ?? this.acceptedByUid,
        completedAt: completedAt ?? this.completedAt,
        completedByUid: completedByUid ?? this.completedByUid,
        dismissedAt: dismissedAt ?? this.dismissedAt,
      );

  Map<String, dynamic> toMap() => {
        'text': text.trim(),
        'employeeName': employeeName.trim(),
        if (employeeProfileKey != null)
          'employeeProfileKey': employeeProfileKey,
        if (presetId != null) 'presetId': presetId,
        'status': status.firestoreValue,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
        if (acceptedByUid != null) 'acceptedByUid': acceptedByUid,
        if (completedAt != null)
          'completedAt': Timestamp.fromDate(completedAt!),
        if (completedByUid != null) 'completedByUid': completedByUid,
        if (dismissedAt != null)
          'dismissedAt': Timestamp.fromDate(dismissedAt!),
      };

  factory StaffRequest.fromMap(String id, Map<String, dynamic> data) {
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return StaffRequest(
      id: id,
      text: (data['text'] as String? ?? '').trim(),
      employeeName: (data['employeeName'] as String? ?? '').trim(),
      employeeProfileKey: data['employeeProfileKey'] as String?,
      presetId: data['presetId'] as String?,
      status: StaffRequestStatusX.parse(data['status'] as String?),
      createdAt: asDate(data['createdAt']),
      acceptedAt: asDate(data['acceptedAt']),
      acceptedByUid: data['acceptedByUid'] as String?,
      completedAt: asDate(data['completedAt']),
      completedByUid: data['completedByUid'] as String?,
      dismissedAt: asDate(data['dismissedAt']),
    );
  }

  factory StaffRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StaffRequest.fromMap(doc.id, doc.data() ?? {});
}
