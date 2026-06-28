import 'submission.dart';

/// What the team is competing on.
enum ChallengeMetric { revenue, memberships, washes, ba }

/// How often the challenge resets.
enum ChallengePeriod { day, week, month, quarter }

extension ChallengeMetricX on ChallengeMetric {
  String get label => switch (this) {
        ChallengeMetric.revenue => 'Revenue',
        ChallengeMetric.memberships => 'Memberships sold',
        ChallengeMetric.washes => 'Cars washed',
        ChallengeMetric.ba => 'Team BA %',
      };
}

extension ChallengePeriodX on ChallengePeriod {
  String get label => switch (this) {
        ChallengePeriod.day => 'Today',
        ChallengePeriod.week => 'This week',
        ChallengePeriod.month => 'This month',
        ChallengePeriod.quarter => 'This quarter',
      };
}

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// A team challenge with a reward, configured by the manager. Progress is
/// computed live from submissions in the current [period] window.
class Challenge {
  const Challenge({
    required this.title,
    required this.reward,
    required this.metric,
    required this.period,
    required this.target,
    this.active = true,
  });

  final String title;
  final String reward;
  final ChallengeMetric metric;
  final ChallengePeriod period;
  final double target;
  final bool active;

  Challenge copyWith({
    String? title,
    String? reward,
    ChallengeMetric? metric,
    ChallengePeriod? period,
    double? target,
    bool? active,
  }) =>
      Challenge(
        title: title ?? this.title,
        reward: reward ?? this.reward,
        metric: metric ?? this.metric,
        period: period ?? this.period,
        target: target ?? this.target,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'reward': reward,
        'metric': metric.name,
        'period': period.name,
        'target': target,
        'active': active,
      };

  static Challenge? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return Challenge(
      title: m['title'] as String? ?? 'Team challenge',
      reward: m['reward'] as String? ?? '',
      metric: _byName(ChallengeMetric.values, m['metric'],
          ChallengeMetric.revenue),
      period: _byName(ChallengePeriod.values, m['period'],
          ChallengePeriod.week),
      target: (m['target'] as num?)?.toDouble() ?? 0,
      active: m['active'] as bool? ?? true,
    );
  }
}

/// [start, end) for the current window of [period] containing [now].
(DateTime, DateTime) challengeWindow(ChallengePeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case ChallengePeriod.day:
      return (today, today.add(const Duration(days: 1)));
    case ChallengePeriod.week:
      final start = today.subtract(Duration(days: today.weekday - 1));
      return (start, start.add(const Duration(days: 7)));
    case ChallengePeriod.month:
      return (DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1));
    case ChallengePeriod.quarter:
      final q = ((now.month - 1) ~/ 3) * 3 + 1;
      return (DateTime(now.year, q, 1), DateTime(now.year, q + 3, 1));
  }
}

/// The team's current value for [c]'s metric across the active window.
double challengeValue(Challenge c, List<Submission> subs) {
  final (start, end) = challengeWindow(c.period, DateTime.now());
  final win = subs.where(
      (s) => !s.submittedAt.isBefore(start) && s.submittedAt.isBefore(end));
  switch (c.metric) {
    case ChallengeMetric.revenue:
      return win.fold(0.0, (a, s) => a + s.grandTotalRevenue);
    case ChallengeMetric.memberships:
      return win.fold(0, (a, s) => a + s.totalMemberships).toDouble();
    case ChallengeMetric.washes:
      return win.fold(0, (a, s) => a + s.totalWashes).toDouble();
    case ChallengeMetric.ba:
      final m = win.fold(0, (a, s) => a + s.totalMemberships);
      final w = win.fold(0, (a, s) => a + s.totalWashes);
      return w == 0 ? 0 : m / w * 100;
  }
}
