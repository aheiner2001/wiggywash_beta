import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/utils/xlsx.dart';

void main() {
  test('buildMasterSheetXlsx returns non-empty xlsx bytes', () {
    final subs = [
      Submission(
        id: '1',
        employeeName: 'Alex',
        baGoal: 40,
        counts: const {},
        submittedAt: DateTime(2026, 3, 8),
        approved: true,
        talkedTo: 5,
      ),
    ];
    final rows = [
      MasterSheetRow(label: 'Alex', submission: subs.first),
    ];
    final totals = subs.first;
    final bytes = buildMasterSheetXlsx(
      rows: rows,
      totals: totals,
      title: 'Wiggy Wash · Mar 8, 2026',
      viewLabel: 'Team',
    );
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });

  test('masterSheetToTsv includes header and totals row', () {
    final s = Submission(
      id: '1',
      employeeName: 'Alex',
      baGoal: 40,
      counts: const {},
      submittedAt: DateTime(2026, 3, 8),
      approved: true,
    );
    final tsv = masterSheetToTsv(
      rows: [MasterSheetRow(label: 'Alex', submission: s)],
      totals: s,
      title: 'Test',
      viewLabel: 'Team',
    );
    expect(tsv.contains('TOTALS'), isTrue);
    expect(tsv.contains('Alex'), isTrue);
  });
}
