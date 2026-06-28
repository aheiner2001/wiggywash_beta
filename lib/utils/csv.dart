import '../models/scorecard_config.dart';
import '../models/submission.dart';

String _esc(Object? v) {
  final s = '${v ?? ''}';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Builds a spreadsheet-friendly CSV of [subs]: one row per submission with a
/// column for every line item plus section totals, BA, and revenue.
String submissionsToCsv(List<Submission> subs) {
  final items = kLineItems;
  final header = <String>[
    'Date',
    'Time',
    'Employee',
    'Talked To',
    'BA Goal %',
    'BA %',
    for (final i in items) i.label,
    'Memberships',
    'Above Eco',
    'Singles',
    'Shop',
    'Overall Score',
    'Revenue',
    'Approved',
    'Edited',
  ];

  final rows = <String>[header.map(_esc).join(',')];

  final sorted = [...subs]
    ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

  for (final s in sorted) {
    final d = s.submittedAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final row = <Object?>[
      date,
      time,
      s.employeeName,
      s.talkedTo,
      s.baGoal.toStringAsFixed(0),
      s.businessAverage.toStringAsFixed(0),
      for (final i in items) s.countOf(i.id),
      s.totalMemberships,
      s.aboveEco,
      s.totalSingleWashes,
      s.totalShopSales,
      s.overallScore,
      s.grandTotalRevenue.toStringAsFixed(2),
      s.approved ? 'yes' : '',
      s.wasEdited ? 'yes' : '',
    ];
    rows.add(row.map(_esc).join(','));
  }

  return rows.join('\n');
}
