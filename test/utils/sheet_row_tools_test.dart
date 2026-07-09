import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/utils/sheet_column.dart';
import 'package:wiggywash/utils/sheet_row_tools.dart';
import 'package:wiggywash/utils/sheet_tools_prefs.dart';
import 'package:wiggywash/utils/xlsx.dart';

Submission _sub({
  required String name,
  required DateTime at,
  int talkedTo = 10,
  Map<String, int> counts = const {},
}) {
  return Submission(
    id: '${name}_${at.millisecondsSinceEpoch}',
    employeeName: name,
    baGoal: 40,
    counts: counts,
    submittedAt: at,
    approved: true,
    talkedTo: talkedTo,
  );
}

void main() {
  final alex = MasterSheetRow(
    label: 'Alex',
    submission: _sub(
      name: 'Alex',
      at: DateTime(2026, 7, 1),
      talkedTo: 10,
      counts: const {'basic': 4},
    ),
  );
  final blake = MasterSheetRow(
    label: 'Blake',
    submission: _sub(
      name: 'Blake',
      at: DateTime(2026, 7, 1),
      talkedTo: 20,
      counts: const {},
    ),
  );

  test('filter by employee names (session filter)', () {
    final out = applySheetRowTools(
      rows: [alex, blake],
      prefs: SheetToolsPrefs.defaults(),
      selectedEmployees: {'Alex'},
      firstColIsDate: false,
    );
    expect(out.map((r) => r.label).toList(), ['Alex']);
  });

  test('filter min BA and min revenue', () {
    final high = MasterSheetRow(
      label: 'Casey',
      submission: _sub(
        name: 'Casey',
        at: DateTime(2026, 7, 1),
        talkedTo: 10,
        counts: const {'basic': 5},
      ),
    );
    final prefs = SheetToolsPrefs.defaults().copyWith(minBa: 1, minRevenue: 0);
    final out = applySheetRowTools(
      rows: [blake, high],
      prefs: prefs,
      selectedEmployees: null,
      firstColIsDate: false,
    );
    expect(out.every((r) => r.submission.businessAverage >= 1), isTrue);
  });

  test('sort by revenue desc keeps order of values', () {
    final a = MasterSheetRow(
      label: 'A',
      submission: _sub(name: 'A', at: DateTime(2026, 7, 1), counts: const {'basic': 1}),
    );
    final b = MasterSheetRow(
      label: 'B',
      submission: _sub(name: 'B', at: DateTime(2026, 7, 1), counts: const {'basic': 3}),
    );
    final prefs = SheetToolsPrefs.defaults().copyWith(
      sortKey: SheetSortKey.revenue,
      sortAsc: false,
    );
    final out = applySheetRowTools(
      rows: [a, b],
      prefs: prefs,
      selectedEmployees: null,
      firstColIsDate: false,
    );
    expect(
      out.first.submission.grandTotalRevenue >=
          out.last.submission.grandTotalRevenue,
      isTrue,
    );
  });

  test('sort by name ascending', () {
    final prefs = SheetToolsPrefs.defaults();
    final out = applySheetRowTools(
      rows: [blake, alex],
      prefs: prefs,
      selectedEmployees: null,
      firstColIsDate: false,
    );
    expect(out.map((r) => r.label).toList(), ['Alex', 'Blake']);
  });

  test('employee filter ignored when firstColIsDate (month/member day rows)', () {
    final day = MasterSheetRow(
      label: '7/1',
      submission: _sub(name: 'Alex', at: DateTime(2026, 7, 1)),
    );
    final out = applySheetRowTools(
      rows: [day],
      prefs: SheetToolsPrefs.defaults(),
      selectedEmployees: {'Nobody'},
      firstColIsDate: true,
    );
    expect(out.length, 1);
  });
}
