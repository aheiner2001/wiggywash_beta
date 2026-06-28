import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/challenge.dart';
import '../services/store.dart';
import '../theme.dart';

final _money = NumberFormat.simpleCurrency(decimalDigits: 0);

String _fmt(ChallengeMetric m, double v) {
  switch (m) {
    case ChallengeMetric.revenue:
      return _money.format(v);
    case ChallengeMetric.ba:
      return '${v.toStringAsFixed(0)}%';
    case ChallengeMetric.memberships:
    case ChallengeMetric.washes:
      return v.toStringAsFixed(0);
  }
}

/// Live team-challenge card. When [onEdit] is provided (manager view) it shows
/// an edit affordance and a "set a challenge" prompt when none is active.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({super.key, this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final c = Store.instance.challenge;
        if (c == null || !c.active) {
          if (onEdit == null) return const SizedBox.shrink();
          return AppCard(
            onTap: onEdit,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.navy),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Set a team challenge & reward',
                      style: TextStyles.subheading),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          );
        }

        final value = challengeValue(c, Store.instance.approvedSubmissions);
        final frac = c.target <= 0 ? 0.0 : (value / c.target).clamp(0.0, 1.0);
        final done = c.target > 0 && value >= c.target;

        return AppCard(
          onTap: onEdit,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    done
                        ? Icons.emoji_events_rounded
                        : Icons.emoji_events_outlined,
                    color: done ? AppColors.warning : AppColors.navy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: TextStyles.subheading),
                        Text('${c.metric.label} · ${c.period.label}',
                            style: TextStyles.caption),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 12,
                  backgroundColor: AppColors.blueSoft,
                  valueColor: AlwaysStoppedAnimation(
                      done ? AppColors.success : AppColors.blue),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_fmt(c.metric, value)} of ${_fmt(c.metric, c.target)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text('${(frac * 100).toStringAsFixed(0)}%',
                      style: TextStyles.caption),
                ],
              ),
              if (c.reward.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        done
                            ? Icons.celebration_rounded
                            : Icons.card_giftcard_rounded,
                        size: 18,
                        color: done ? AppColors.success : AppColors.navy,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          done ? 'Goal hit! Reward: ${c.reward}' : c.reward,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: done ? AppColors.success : AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
