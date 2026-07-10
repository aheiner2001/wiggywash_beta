import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// Compact per-employee scorecard for dashboard Cards mode.
class MiniScorecardCard extends StatelessWidget {
  const MiniScorecardCard({
    super.key,
    required this.name,
    required this.submissions,
    this.compact = false,
  });

  final String name;
  final List<Submission> submissions;
  final bool compact;

  int _count(String id) =>
      submissions.fold(0, (s, e) => s + e.countOf(id));

  @override
  Widget build(BuildContext context) {
    final revenue =
        submissions.fold(0.0, (s, e) => s + e.grandTotalRevenue);
    final memberships =
        submissions.fold(0, (s, e) => s + e.totalMemberships);
    final singles =
        submissions.fold(0, (s, e) => s + e.totalSingleWashes);
    final totalWashes = memberships + singles;
    final conv =
        totalWashes == 0 ? 0.0 : memberships / totalWashes * 100;
    final latestGoal = submissions.isEmpty
        ? 0.0
        : submissions
            .reduce((a, b) =>
                a.submittedAt.isAfter(b.submittedAt) ? a : b)
            .baGoal;
    final badgeColor = baColor(conv, latestGoal);
    final sections = Store.instance.enabledSections;

    if (compact) {
      return AppCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'BA ${conv.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _money.format(revenue),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$memberships mem · $singles wash',
              style: TextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: TextStyles.subheading),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'BA ${conv.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          for (final section in sections) ...[
            Builder(builder: (context) {
              final rows = <Widget>[];
              for (final item in itemsFor(section)) {
                final c = _count(item.id);
                if (c <= 0) continue;
                rows.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(item.label,
                              style: TextStyles.caption
                                  .copyWith(color: AppColors.textPrimary)),
                        ),
                        Text('×$c',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                );
              }
              if (rows.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      section.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.roseText,
                      ),
                    ),
                  ),
                  ...rows,
                ],
              );
            }),
          ],
          const SizedBox(height: 8),
          Text(_money.format(revenue), style: TextStyles.subheading),
        ],
      ),
    );
  }
}
