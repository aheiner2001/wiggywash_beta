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

class EmployeeBa {
  const EmployeeBa({required this.name, required this.ba});
  final String name;
  final double ba;
}

class EmployeeWashMix {
  const EmployeeWashMix({
    required this.name,
    required this.memberships,
    required this.singles,
  });
  final String name;
  final int memberships;
  final int singles;
}

class MasterSheetStats {
  const MasterSheetStats({
    required this.totalRevenue,
    required this.shiftCount,
    required this.avgRevenuePerShift,
    required this.revenueByDay,
    required this.employeeTotals,
    required this.employeeBa,
    required this.membershipMix,
  });

  final double totalRevenue;
  final int shiftCount;
  final double avgRevenuePerShift;
  final List<DayRevenue> revenueByDay;
  final List<EmployeeRevenue> employeeTotals;
  final List<EmployeeBa> employeeBa;
  final List<EmployeeWashMix> membershipMix;
}

double _baFor(List<Submission> subs) {
  var memb = 0;
  var talked = 0;
  var washes = 0;
  for (final s in subs) {
    memb += s.totalMemberships;
    talked += s.talkedTo;
    washes += s.totalWashes;
  }
  if (talked > 0) return memb / talked * 100;
  if (washes == 0) return 0;
  return memb / washes * 100;
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
      employeeBa: [],
      membershipMix: [],
    );
  }

  var total = 0.0;
  final byDay = <DateTime, double>{};
  final byName = <String, double>{};
  final byNameSubs = <String, List<Submission>>{};

  for (final s in inRange) {
    final rev = s.grandTotalRevenue;
    total += rev;
    final day =
        DateTime(s.submittedAt.year, s.submittedAt.month, s.submittedAt.day);
    byDay[day] = (byDay[day] ?? 0) + rev;
    byName[s.employeeName] = (byName[s.employeeName] ?? 0) + rev;
    byNameSubs.putIfAbsent(s.employeeName, () => []).add(s);
  }

  final days = byDay.keys.toList()..sort();
  final revenueByDay = [
    for (final d in days) DayRevenue(day: d, revenue: byDay[d]!),
  ];

  final ranked = byName.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  List<EmployeeRevenue> employeeTotals;
  List<EmployeeBa> employeeBa;
  List<EmployeeWashMix> membershipMix;

  if (ranked.length <= employeeTopN) {
    employeeTotals = [
      for (final e in ranked) EmployeeRevenue(name: e.key, revenue: e.value),
    ];
    employeeBa = [
      for (final e in ranked)
        EmployeeBa(name: e.key, ba: _baFor(byNameSubs[e.key]!)),
    ];
    membershipMix = [
      for (final e in ranked)
        EmployeeWashMix(
          name: e.key,
          memberships: byNameSubs[e.key]!
              .fold(0, (n, s) => n + s.totalMemberships),
          singles: byNameSubs[e.key]!
              .fold(0, (n, s) => n + s.totalSingleWashes),
        ),
    ];
  } else {
    final top = ranked.take(employeeTopN).toList();
    final rest = ranked.skip(employeeTopN).toList();
    final otherRev =
        rest.fold<double>(0, (s, e) => s + e.value);
    final otherSubs = [
      for (final e in rest) ...byNameSubs[e.key]!,
    ];
    employeeTotals = [
      for (final e in top) EmployeeRevenue(name: e.key, revenue: e.value),
      EmployeeRevenue(name: 'Other', revenue: otherRev),
    ];
    employeeBa = [
      for (final e in top)
        EmployeeBa(name: e.key, ba: _baFor(byNameSubs[e.key]!)),
      EmployeeBa(name: 'Other', ba: _baFor(otherSubs)),
    ];
    membershipMix = [
      for (final e in top)
        EmployeeWashMix(
          name: e.key,
          memberships: byNameSubs[e.key]!
              .fold(0, (n, s) => n + s.totalMemberships),
          singles: byNameSubs[e.key]!
              .fold(0, (n, s) => n + s.totalSingleWashes),
        ),
      EmployeeWashMix(
        name: 'Other',
        memberships:
            otherSubs.fold(0, (n, s) => n + s.totalMemberships),
        singles: otherSubs.fold(0, (n, s) => n + s.totalSingleWashes),
      ),
    ];
  }

  return MasterSheetStats(
    totalRevenue: total,
    shiftCount: inRange.length,
    avgRevenuePerShift: total / inRange.length,
    revenueByDay: revenueByDay,
    employeeTotals: employeeTotals,
    employeeBa: employeeBa,
    membershipMix: membershipMix,
  );
}
