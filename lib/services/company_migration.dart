import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company.dart';

/// Copies root-level locations (and their subcollections) into
/// `companies/{companyId}/locations/`. Safe to run once.
Future<String?> migrateToCompany({
  required FirebaseFirestore db,
  required String companyId,
  required String companyName,
  required String companyCode,
}) async {
  try {
    final companyRef = db.collection('companies').doc(companyId);
    await companyRef.set(Company(
      id: companyId,
      name: companyName,
      companyCode: companyCode,
      status: CompanyStatus.active,
      createdAt: DateTime.now(),
    ).toMap());

    final legacyLocs = await db.collection('locations').get();
    for (final locDoc in legacyLocs.docs) {
      final dest = companyRef.collection('locations').doc(locDoc.id);
      await dest.set(locDoc.data());
      for (final sub in ['submissions', 'workers', 'config']) {
        final subSnap = await locDoc.reference.collection(sub).get();
        final batch = db.batch();
        for (final d in subSnap.docs) {
          batch.set(dest.collection(sub).doc(d.id), d.data());
        }
        await batch.commit();
      }
    }
    return null;
  } catch (e) {
    return 'Company migration failed: $e';
  }
}
