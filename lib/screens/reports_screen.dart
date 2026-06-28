import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _time = DateFormat('h:mm a');

/// Read-only reports view. Shows today's submitted scorecards. When
/// [filterName] is set, only that employee's shifts appear; otherwise it shows
/// the whole team (used when the manager enables "see all").
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.title,
    this.filterName,
  });

  final String title;
  final String? filterName;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          // Team view shows approved scorecards only; a personal view (filtered
          // to one name) shows that person's own saved cards, pending included.
          final source = filterName == null
              ? Store.instance.approvedSubmissions
              : Store.instance.submissions;
          final subs = source.where((s) {
            if (!_isToday(s.submittedAt)) return false;
            if (filterName == null) return true;
            return s.employeeName.toLowerCase() == filterName!.toLowerCase();
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                children: [
                  _TotalsCard(
                    label: filterName == null ? 'Team total today' : 'Your total today',
                    submissions: subs,
                  ),
                  const SizedBox(height: 12),
                  if (subs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'No submitted shifts yet today.',
                        textAlign: TextAlign.center,
                        style: TextStyles.caption,
                      ),
                    )
                  else if (filterName == null)
                    ..._byEmployee(subs).entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EmployeeReport(name: e.key, submissions: e.value),
                          ),
                        )
                  else
                    _FullBreakdown(submissions: subs),
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

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.label, required this.submissions});
  final String label;
  final List<Submission> submissions;

  @override
  Widget build(BuildContext context) {
    final revenue = submissions.fold(0.0, (s, e) => s + e.grandTotalRevenue);
    final memberships = submissions.fold(0, (s, e) => s + e.totalMemberships);
    final singles = submissions.fold(0, (s, e) => s + e.totalSingleWashes);
    final shop = submissions.fold(0, (s, e) => s + e.totalShopSales);
    final totalWashes = memberships + singles;
    final conv = totalWashes == 0 ? 0.0 : memberships / totalWashes * 100;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyles.subheading),
              Text(_money.format(revenue),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Tile(label: 'Members', value: '$memberships'),
              _Tile(label: 'Singles', value: '$singles'),
              _Tile(label: 'Shop', value: '$shop'),
              _Tile(label: 'BA', value: '${conv.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 6),
          Text('${submissions.length} shift(s) today', style: TextStyles.caption),
        ],
      ),
    );
  }
}

class _EmployeeReport extends StatelessWidget {
  const _EmployeeReport({required this.name, required this.submissions});
  final String name;
  final List<Submission> submissions;

  @override
  Widget build(BuildContext context) {
    final revenue = submissions.fold(0.0, (s, e) => s + e.grandTotalRevenue);
    final memberships = submissions.fold(0, (s, e) => s + e.totalMemberships);
    final singles = submissions.fold(0, (s, e) => s + e.totalSingleWashes);
    final totalWashes = memberships + singles;
    final conv = totalWashes == 0 ? 0.0 : memberships / totalWashes * 100;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                  '$memberships members • $singles singles • BA ${conv.toStringAsFixed(0)}%',
                  style: TextStyles.caption,
                ),
              ],
            ),
          ),
          Text(_money.format(revenue),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.success,
              )),
        ],
      ),
    );
  }
}

/// The employee's own line-by-line breakdown for the day — mirrors the
/// per-employee breakdown the manager sees. Aggregates every shift, grouped by
/// section (memberships, singles, shop), with each shift's revenue listed at
/// the bottom.
class _FullBreakdown extends StatelessWidget {
  const _FullBreakdown({required this.submissions});
  final List<Submission> submissions;

  int _count(String id) => submissions.fold(0, (s, e) => s + e.countOf(id));

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: const Text('Full breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              )),
          children: [
            for (final section in Store.instance.enabledSections) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
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
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
            const Divider(height: 24),
            for (final s in submissions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Shift at ${_time.format(s.submittedAt)}',
                        style: TextStyles.caption),
                    Text(_money.format(s.grandTotalRevenue),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        )),
                  ],
                ),
              ),
          ],
        ),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                )),
            const SizedBox(height: 2),
            Text(label,
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
