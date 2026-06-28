import 'package:cloud_firestore/cloud_firestore.dart';

/// A team member a manager adds to a location's roster. Employees pick their
/// name from this list (after entering the site code). An optional [pin]
/// requires a short code to sign in.
class Worker {
  const Worker({required this.id, required this.name, this.pin});

  final String id;
  final String name;

  /// Optional entry code. When set, the employee must type it to sign in.
  final String? pin;

  bool get requiresPin => pin != null && pin!.trim().isNotEmpty;

  bool verifyPin(String input) =>
      pin!.trim().toLowerCase() == input.trim().toLowerCase();

  Map<String, dynamic> toMap() => {
        'name': name,
        if (pin != null && pin!.isNotEmpty) 'pin': pin,
      };

  factory Worker.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPin = data['pin'] as String?;
    return Worker(
      id: doc.id,
      name: data['name'] as String? ?? '',
      pin: rawPin != null && rawPin.trim().isNotEmpty ? rawPin.trim() : null,
    );
  }

  Worker copyWith({String? name, String? pin, bool clearPin = false}) => Worker(
        id: id,
        name: name ?? this.name,
        pin: clearPin ? null : (pin ?? this.pin),
      );
}
