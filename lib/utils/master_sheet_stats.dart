import '../models/submission.dart';

class DayRevenue {
  const DayRevenue({required this.day, required this.revenue});
  final DateTime day; // date-only (year, month, day)
  final double revenue;
}

class EmployeeRevenue {
  const EmployeeRevenue({required this.name, required this.revenue});
  final String name;
  final double revenue;
}

class MasterSheetStats {
  const MasterSheetStats({
    required this.totalRevenue,
    required this.shiftCount,
    required this.avgRevenuePerShift,
    required this.revenueByDay,
    required this.employeeTotals,
  });

  final double totalRevenue;
  final int shiftCount;
  final double avgRevenuePerShift;
  final List<DayRevenue> revenueByDay;
  final List<EmployeeRevenue> employeeTotals;
}

/// Aggregates [submissions] in `[rangeStart, rangeEndExclusive)`.
MasterSheetStats buildMasterSheetStats({
  required List<Submission> submissions,
  required DateTime rangeStart,
  required DateTime rangeEndExclusive,
  int employeeTopN = 8,
}) {
  final inRange = submissions.where((s) {
    final t = s.submittedAt;
    return !t.isBefore(rangeStart) && t.isBefore(rangeEndExclusive);
  }).toList();

  if (inRange.isEmpty) {
    return const MasterSheetStats(
      totalRevenue: 0,
      shiftCount: 0,
      avgRevenuePerShift: 0,
      revenueByDay: [],
      employeeTotals: [],
    );
  }

  var total = 0.0;
  final byDay = <DateTime, double>{};
  final byName = <String, double>{};

  for (final s in inRange) {
    final rev = s.grandTotalRevenue;
    total += rev;
    final day =
        DateTime(s.submittedAt.year, s.submittedAt.month, s.submittedAt.day);
    byDay[day] = (byDay[day] ?? 0) + rev;
    byName[s.employeeName] = (byName[s.employeeName] ?? 0) + rev;
  }

  final days = byDay.keys.toList()..sort();
  final revenueByDay = [
    for (final d in days) DayRevenue(day: d, revenue: byDay[d]!),
  ];

  final ranked = byName.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final List<EmployeeRevenue> employeeTotals;
  if (ranked.length <= employeeTopN) {
    employeeTotals = [
      for (final e in ranked) EmployeeRevenue(name: e.key, revenue: e.value),
    ];
  } else {
    final top = ranked.take(employeeTopN).toList();
    final other =
        ranked.skip(employeeTopN).fold<double>(0, (s, e) => s + e.value);
    employeeTotals = [
      for (final e in top) EmployeeRevenue(name: e.key, revenue: e.value),
      EmployeeRevenue(name: 'Other', revenue: other),
    ];
  }

  return MasterSheetStats(
    totalRevenue: total,
    shiftCount: inRange.length,
    avgRevenuePerShift: total / inRange.length,
    revenueByDay: revenueByDay,
    employeeTotals: employeeTotals,
  );
}
