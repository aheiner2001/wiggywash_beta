import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// Full tally card — name + BA badge, section headers, line ×counts, total $.
/// Used for manager Cards view and the Share to chat preview.
class MiniScorecardCard extends StatelessWidget {
  const MiniScorecardCard({
    super.key,
    required this.name,
    required this.submissions,
  });

  final String name;
  final List<Submission> submissions;

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

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    fontSize: 12,
                    letterSpacing: 0.3,
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
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '×$c',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (rows.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      section.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                        color: AppColors.roseText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...rows,
                ],
              );
            }),
          ],
          const SizedBox(height: 12),
          Text(
            _money.format(revenue),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
