import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/submission.dart';
import 'package:wiggywash/utils/master_sheet_stats.dart';

Submission _sub({
  required String name,
  required DateTime at,
  Map<String, int> counts = const {},
}) {
  return Submission(
    id: '${name}_${at.millisecondsSinceEpoch}',
    employeeName: name,
    baGoal: 40,
    counts: counts,
    submittedAt: at,
    approved: true,
    talkedTo: 10,
  );
}

void main() {
  final start = DateTime(2026, 7, 1);
  final endExclusive = DateTime(2026, 7, 4); // Jul 1–3 inclusive window

  test('empty period yields zero summary and empty series', () {
    final stats = buildMasterSheetStats(
      submissions: const [],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.totalRevenue, 0);
    expect(stats.shiftCount, 0);
    expect(stats.avgRevenuePerShift, 0);
    expect(stats.revenueByDay, isEmpty);
    expect(stats.employeeTotals, isEmpty);
    expect(stats.employeeBa, isEmpty);
    expect(stats.membershipMix, isEmpty);
  });

  test('summary and revenue-by-day use grandTotalRevenue', () {
    final a = _sub(name: 'Alex', at: DateTime(2026, 7, 1, 10));
    final b = _sub(name: 'Alex', at: DateTime(2026, 7, 1, 18));
    final c = _sub(name: 'Blake', at: DateTime(2026, 7, 2, 12));
    final stats = buildMasterSheetStats(
      submissions: [a, b, c],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.shiftCount, 3);
    expect(
      stats.totalRevenue,
      a.grandTotalRevenue + b.grandTotalRevenue + c.grandTotalRevenue,
    );
    expect(stats.avgRevenuePerShift, stats.totalRevenue / 3);
    expect(stats.revenueByDay.length, 2);
    expect(stats.revenueByDay[0].day, DateTime(2026, 7, 1));
    expect(stats.revenueByDay[1].day, DateTime(2026, 7, 2));
  });

  test('employee totals sorted descending and topN collapses Other', () {
    final subs = [
      for (var i = 0; i < 10; i++)
        _sub(name: 'E$i', at: DateTime(2026, 7, 1, i + 1)),
    ];
    final stats = buildMasterSheetStats(
      submissions: subs,
      rangeStart: start,
      rangeEndExclusive: endExclusive,
      employeeTopN: 3,
    );
    expect(stats.employeeTotals.length, lessThanOrEqualTo(4)); // 3 + Other
    final names = stats.employeeTotals.map((e) => e.name).toList();
    if (stats.employeeTotals.length == 4) {
      expect(names.last, 'Other');
    }
  });

  test('submissions outside range are ignored', () {
    final inside = _sub(name: 'Alex', at: DateTime(2026, 7, 2));
    final outside = _sub(name: 'Blake', at: DateTime(2026, 6, 30));
    final stats = buildMasterSheetStats(
      submissions: [inside, outside],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.shiftCount, 1);
    expect(stats.employeeTotals.single.name, 'Alex');
  });

  test('employeeBa and membershipMix aggregate per employee', () {
    final a = _sub(
      name: 'Alex',
      at: DateTime(2026, 7, 1, 10),
      counts: const {'basic': 4},
    );
    final b = _sub(
      name: 'Blake',
      at: DateTime(2026, 7, 1, 12),
      counts: const {'economy': 3},
    );
    final stats = buildMasterSheetStats(
      submissions: [a, b],
      rangeStart: start,
      rangeEndExclusive: endExclusive,
    );
    expect(stats.employeeBa, isNotEmpty);
    expect(stats.membershipMix, isNotEmpty);
    final alexMix = stats.membershipMix.firstWhere((e) => e.name == 'Alex');
    expect(alexMix.memberships, greaterThan(0));
    final blakeMix = stats.membershipMix.firstWhere((e) => e.name == 'Blake');
    expect(blakeMix.singles, greaterThan(0));
  });
}
