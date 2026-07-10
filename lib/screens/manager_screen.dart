import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/csv.dart';
import '../utils/exporter.dart';
import '../utils/ui_density.dart';
import '../widgets/challenge_card.dart';
import '../widgets/google_review_qr.dart';
import '../widgets/mini_scorecard_card.dart';
import '../widgets/profile_menu.dart';
import '../widgets/store_message.dart';
import '../widgets/ui_kit.dart';
import 'challenge_editor_screen.dart';
import 'tips_screen.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _dayLabel = DateFormat('EEEE, MMM d');
final _time = DateFormat('h:mm a');

enum _Period { day, week, month }

enum _PeopleLayout { list, cards }

const _kPeopleLayout = 'ww_dashboard_people_layout';

final _monthLabel = DateFormat('MMMM yyyy');
final _shortDay = DateFormat('M/d');

/// Manager view: live team totals + per-employee breakdown, filterable by day,
/// week, or month.
class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  DateTime _day = DateTime.now();
  _Period _period = _Period.day;
  _PeopleLayout _peopleLayout = _PeopleLayout.list;

  UiDensity get _density => UiDensityController.instance.density;

  @override
  void initState() {
    super.initState();
    _loadPeopleLayout();
    UiDensityController.instance.addListener(_onDensityChanged);
  }

  void _onDensityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UiDensityController.instance.removeListener(_onDensityChanged);
    super.dispose();
  }

  Future<void> _loadPeopleLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPeopleLayout);
    if (!mounted) return;
    if (raw == _PeopleLayout.cards.name) {
      setState(() => _peopleLayout = _PeopleLayout.cards);
    }
  }

  Future<void> _setPeopleLayout(_PeopleLayout layout) async {
    setState(() => _peopleLayout = layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPeopleLayout, layout.name);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// [start, end) range for the current period anchored on [_day].
  (DateTime, DateTime) _range() {
    final d = DateTime(_day.year, _day.month, _day.day);
    switch (_period) {
      case _Period.day:
        return (d, d.add(const Duration(days: 1)));
      case _Period.week:
        final start = d.subtract(Duration(days: d.weekday - 1)); // Monday
        return (start, start.add(const Duration(days: 7)));
      case _Period.month:
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 1);
        return (start, end);
    }
  }

  bool _inRange(DateTime t) {
    final (start, end) = _range();
    return !t.isBefore(start) && t.isBefore(end);
  }

  String get _rangeLabel {
    final (start, end) = _range();
    switch (_period) {
      case _Period.day:
        return _dayLabel.format(_day);
      case _Period.week:
        final lastDay = end.subtract(const Duration(days: 1));
        return '${_shortDay.format(start)} – ${_shortDay.format(lastDay)}';
      case _Period.month:
        return _monthLabel.format(_day);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _useScorecard() async {
    final workers = Store.instance.workers;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Fill out a scorecard'),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (workers.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'No names on the roster yet. Add team members in '
                '“Team & Site Code” first.',
                style: TextStyles.caption,
              ),
            )
          else
            for (final w in workers)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Text(
                    w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(w.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
                onTap: () => Navigator.pop(ctx, w.name),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    Store.instance.enterEmployeeMode(name);
  }

  Future<void> _resetDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset this day?'),
        content: Text(
            'This permanently deletes every submission from ${_dayLabel.format(_day)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await Store.instance.resetDay(_day);
  }

  Future<void> _export(List<Submission> subs) async {
    if (subs.isEmpty) {
      showStoreMessage(context, 'Nothing to export for this period.',
          error: true);
      return;
    }
    final loc = Store.instance.activeLocation?.name ?? 'wiggywash';
    final slug = loc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final (start, _) = _range();
    final stamp =
        '${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}';
    try {
      await exportCsv('$slug-$stamp-${_period.name}.csv', submissionsToCsv(subs));
    } catch (e) {
      if (mounted) showStoreMessage(context, 'Export failed: $e', error: true);
    }
  }

  void _shiftPeriod(int dir) {
    setState(() {
      switch (_period) {
        case _Period.day:
          _day = _day.add(Duration(days: dir));
        case _Period.week:
          _day = _day.add(Duration(days: 7 * dir));
        case _Period.month:
          _day = DateTime(_day.year, _day.month + dir,
              _day.day.clamp(1, 28));
      }
    });
  }

  ({List<double> values, List<String> labels, String title}) _trendSeries() {
    final subs = Store.instance.approvedSubmissions;
    double revOn(bool Function(DateTime) test) => subs
        .where((s) => test(s.submittedAt))
        .fold(0.0, (a, s) => a + s.grandTotalRevenue);

    switch (_period) {
      case _Period.day:
        final values = <double>[];
        final labels = <String>[];
        final base = DateTime(_day.year, _day.month, _day.day);
        for (var i = 6; i >= 0; i--) {
          final d = base.subtract(Duration(days: i));
          values.add(revOn((t) => _sameDay(t, d)));
          labels.add(_shortDay.format(d));
        }
        return (values: values, labels: labels, title: 'Revenue · last 7 days');
      case _Period.week:
        final (start, _) = _range();
        const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final values = <double>[];
        final labels = <String>[];
        for (var i = 0; i < 7; i++) {
          final d = start.add(Duration(days: i));
          values.add(revOn((t) => _sameDay(t, d)));
          labels.add(wd[i]);
        }
        return (values: values, labels: labels, title: 'Revenue · this week');
      case _Period.month:
        final (start, end) = _range();
        final values = <double>[];
        final labels = <String>[];
        var ws = start;
        var wn = 1;
        while (ws.isBefore(end)) {
          final we = ws.add(const Duration(days: 7));
          values.add(revOn(
              (t) => !t.isBefore(ws) && t.isBefore(we) && t.isBefore(end)));
          labels.add('W$wn');
          ws = we;
          wn++;
        }
        return (values: values, labels: labels, title: 'Revenue · this month');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: Store.instance,
          builder: (context, _) {
            final loc = Store.instance.activeLocation?.displayName;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Team Dashboard'),
                if (loc != null)
                  Text(loc,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      )),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Tips',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const TipsScreen(audience: TipsAudience.manager),
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const GoogleReviewQrButton(),
          IconButton(
            tooltip: 'Fill out a scorecard',
            onPressed: _useScorecard,
            icon: const Icon(Icons.assignment_ind_outlined),
          ),
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () => _export(
              Store.instance.approvedSubmissions
                  .where((s) => _inRange(s.submittedAt))
                  .toList(),
            ),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Pick date',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_today_rounded),
          ),
          IconButton(
            tooltip: 'Reset day',
            onPressed: _resetDay,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const ProfileAction(),
        ],
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final all = Store.instance.approvedSubmissions
              .where((s) => _inRange(s.submittedAt))
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    _peopleLayout == _PeopleLayout.cards ? 1100 : 760,
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  _density.pagePadding,
                  _density.pagePadding,
                  _density.pagePadding,
                  32,
                ),
                children: [
                  _PeriodBar(
                    period: _period,
                    label: _rangeLabel,
                    onPeriodChanged: (p) => setState(() => _period = p),
                    onPrev: () => _shiftPeriod(-1),
                    onNext: () => _shiftPeriod(1),
                    onPickDate: _pickDay,
                  ),
                  SizedBox(height: _density.sectionGap),
                  _TeamTotals(submissions: all),
                  SizedBox(height: _density.sectionGap),
                  if (all.isNotEmpty) ...[
                    SegmentedButton<_PeopleLayout>(
                      segments: const [
                        ButtonSegment(
                          value: _PeopleLayout.list,
                          label: Text('List'),
                          icon: Icon(Icons.view_agenda_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: _PeopleLayout.cards,
                          label: Text('Cards'),
                          icon: Icon(Icons.grid_view_rounded, size: 18),
                        ),
                      ],
                      selected: {_peopleLayout},
                      onSelectionChanged: (s) => _setPeopleLayout(s.first),
                    ),
                    SizedBox(height: _density.sectionGap),
                  ],
                  if (all.isEmpty && Store.instance.submissionsLoading) ...[
                    const SkeletonCard(lines: 3),
                    SizedBox(height: _density.sectionGap - 2),
                    const SkeletonCard(lines: 3),
                  ] else if (all.isEmpty)
                    const _EmptyState()
                  else if (_peopleLayout == _PeopleLayout.list)
                    ...(_byEmployee(all).entries.map(
                          (e) => Padding(
                            padding: EdgeInsets.only(bottom: _density.sectionGap - 2),
                            child: _EmployeeCard(
                              name: e.key,
                              submissions: e.value,
                              padding: _density.peopleCardPadding,
                            ),
                          ),
                        ))
                  else
                    _PeopleCardsGrid(byEmployee: _byEmployee(all)),
                  SizedBox(height: _density.sectionGap + 8),
                  const Text('More', style: TextStyles.caption),
                  SizedBox(height: _density.sectionGap - 4),
                  const _SeeAllToggle(),
                  SizedBox(height: _density.sectionGap),
                  ChallengeCard(
                    onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChallengeEditorScreen(),
                      ),
                    ),
                  ),
                  if (all.isNotEmpty) ...[
                    SizedBox(height: _density.sectionGap),
                    _TrendsCard(series: _trendSeries()),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, List<Submission>> _byEmployee(List<Submission> subs) {
    final map = <String, List<Submission>>{};
    for (final s in subs) {
      map.putIfAbsent(s.employeeName, () => []).add(s);
    }
    return map;
  }
}

class _PeopleCardsGrid extends StatelessWidget {
  const _PeopleCardsGrid({required this.byEmployee});
  final Map<String, List<Submission>> byEmployee;

  @override
  Widget build(BuildContext context) {
    final entries = byEmployee.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Phones: full tally cards stacked (same look as Share preview).
        if (w < 600) {
          return Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                MiniScorecardCard(
                  name: entries[i].key,
                  submissions: entries[i].value,
                ),
              ],
            ],
          );
        }
        final cross = w >= 900 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cross >= 4 ? 0.55 : 0.62,
          ),
          itemBuilder: (context, i) {
            final e = entries[i];
            return MiniScorecardCard(name: e.key, submissions: e.value);
          },
        );
      },
    );
  }
}

/// Manager switch controlling whether employees can see everyone's submissions.
class _SeeAllToggle extends StatelessWidget {
  const _SeeAllToggle();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final on = Store.instance.seeAll;
        return AppCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.visibility_rounded, color: AppColors.navy),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Let everyone see all totals',
                        style: TextStyles.subheading),
                    SizedBox(height: 2),
                    Text(
                      'When on, employees can view the whole team\'s submissions. '
                      'When off, each person only sees their own.',
                      style: TextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: (value) async {
                  final err = await Store.instance.setSeeAll(value);
                  if (context.mounted && err != null) {
                    showStoreMessage(context, err, error: true);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.period,
    required this.label,
    required this.onPeriodChanged,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  final _Period period;
  final String label;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final p in _Period.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _SegChip(
                      label: switch (p) {
                        _Period.day => 'Day',
                        _Period.week => 'Week',
                        _Period.month => 'Month',
                      },
                      selected: p == period,
                      onTap: () => onPeriodChanged(p),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 18, color: AppColors.navy),
                        const SizedBox(width: 8),
                        Text(label, style: TextStyles.subheading),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : AppColors.blueSoft,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.series});
  final ({List<double> values, List<String> labels, String title}) series;

  @override
  Widget build(BuildContext context) {
    final total = series.values.fold(0.0, (a, b) => a + b);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(series.title, style: TextStyles.subheading),
              if (total > 0)
                Text(_money.format(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    )),
            ],
          ),
          const SizedBox(height: 16),
          MiniBarChart(values: series.values, labels: series.labels),
        ],
      ),
    );
  }
}

class _TeamTotals extends StatelessWidget {
  const _TeamTotals({required this.submissions});
  final List<Submission> submissions;

  @override
  Widget build(BuildContext context) {
    final revenue =
        submissions.fold(0.0, (s, e) => s + e.grandTotalRevenue);
    final memberships =
        submissions.fold(0, (s, e) => s + e.totalMemberships);
    final singles = submissions.fold(0, (s, e) => s + e.totalSingleWashes);
    final shop = submissions.fold(0, (s, e) => s + e.totalShopSales);
    final totalWashes = memberships + singles;
    final conv = totalWashes == 0 ? 0.0 : memberships / totalWashes * 100;
    final goals = submissions.where((s) => s.baGoal > 0).toList();
    final avgGoal = goals.isEmpty
        ? 0.0
        : goals.fold(0.0, (s, e) => s + e.baGoal) / goals.length;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Team Revenue', style: TextStyles.subheading),
              AnimatedCount(
                value: revenue,
                format: _money.format,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Tile(label: 'Memberships', value: '$memberships'),
              _Tile(label: 'Singles', value: '$singles'),
              _Tile(label: 'Shop', value: '$shop'),
              _Tile(
                label: 'BA / Goal',
                value:
                    '${conv.toStringAsFixed(0)}% / ${avgGoal.toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${submissions.length} submission(s) today',
              style: TextStyles.caption),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                )),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.name,
    required this.submissions,
    this.padding = 14,
  });
  final String name;
  final List<Submission> submissions;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final revenue = submissions.fold(0.0, (s, e) => s + e.grandTotalRevenue);
    final memberships = submissions.fold(0, (s, e) => s + e.totalMemberships);
    final singles = submissions.fold(0, (s, e) => s + e.totalSingleWashes);
    final shop = submissions.fold(0, (s, e) => s + e.totalShopSales);
    final totalWashes = memberships + singles;
    final conv = totalWashes == 0 ? 0.0 : memberships / totalWashes * 100;
    final latestGoal = submissions
        .reduce((a, b) => a.submittedAt.isAfter(b.submittedAt) ? a : b)
        .baGoal;
    final badgeColor = baColor(conv, latestGoal);

    return AppCard(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyles.subheading),
                    Text(
                      '${submissions.length} shift(s)'
                      '${latestGoal > 0 ? ' • Goal ${latestGoal.toStringAsFixed(0)}%' : ''}',
                      style: TextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'BA ${conv.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Tile(label: 'Members', value: '$memberships'),
              _Tile(label: 'Singles', value: '$singles'),
              _Tile(label: 'Shop', value: '$shop'),
              _Tile(label: 'Revenue', value: _money.format(revenue)),
            ],
          ),
          const SizedBox(height: 12),
          _Breakdown(submissions: submissions),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.submissions});
  final List<Submission> submissions;

  int _count(String id) =>
      submissions.fold(0, (s, e) => s + e.countOf(id));

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('Full breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            )),
        children: [
          for (final section in Store.instance.enabledSections) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(section.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.roseText,
                    )),
              ),
            ),
            for (final item in itemsFor(section))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: TextStyles.body),
                    Text('${_count(item.id)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
              ),
          ],
          const Divider(height: 20),
          for (final s in submissions) _ShiftRow(submission: s),
        ],
      ),
    );
  }
}

/// A single submitted shift in the manager breakdown, with edit/delete actions.
class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.submission});
  final Submission submission;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this submission?'),
        content: Text(
          'Permanently remove ${submission.employeeName}\'s shift from '
          '${_time.format(submission.submittedAt)}? Use this to clear test entries.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final err = await Store.instance.deleteSubmission(submission.id);
    if (!context.mounted) return;
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${submission.employeeName}\'s shift'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => Store.instance.addSubmission(submission),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditSubmissionDialog(submission: submission),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Shift at ${_time.format(submission.submittedAt)}'
              '${submission.wasEdited ? ' • edited' : ''}',
              style: TextStyles.caption,
            ),
          ),
          Text(_money.format(submission.grandTotalRevenue),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              )),
          PopupMenuButton<String>(
            tooltip: 'Edit or delete',
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: AppColors.textMuted),
            onSelected: (v) {
              if (v == 'edit') _edit(context);
              if (v == 'delete') _delete(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Manager dialog to correct a submission's counts and BA goal.
class _EditSubmissionDialog extends StatefulWidget {
  const _EditSubmissionDialog({required this.submission});
  final Submission submission;

  @override
  State<_EditSubmissionDialog> createState() => _EditSubmissionDialogState();
}

class _EditSubmissionDialogState extends State<_EditSubmissionDialog> {
  late final Map<String, int> _counts;
  late final TextEditingController _baGoal;

  @override
  void initState() {
    super.initState();
    _counts = {for (final i in kLineItems) i.id: widget.submission.countOf(i.id)};
    _baGoal = TextEditingController(
        text: widget.submission.baGoal.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _baGoal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = await Store.instance.updateSubmission(
      widget.submission.id,
      counts: Map.of(_counts),
      baGoal: double.tryParse(_baGoal.text.trim()) ?? 0,
    );
    if (!mounted) return;
    Navigator.pop(context);
    showStoreMessage(context, err ?? 'Submission updated', error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.submission.employeeName}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('BA Goal %')),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _baGoal,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                  ],
                ),
              ),
              for (final section in Store.instance.enabledSections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Text(section.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.roseText,
                      )),
                ),
                for (final item in itemsFor(section))
                  _CountStepper(
                    label: item.label,
                    value: _counts[item.id] ?? 0,
                    onChanged: (v) => setState(() => _counts[item.id] = v),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyles.body)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.inbox_rounded,
      title: 'No submissions yet',
      message: 'Employee scorecards will appear here live as the team submits.',
    );
  }
}
