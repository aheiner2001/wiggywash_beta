import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/submission.dart';
import '../theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// Full-page preview before sharing a scorecard snapshot to chat.
class ScorecardSharePreviewScreen extends StatelessWidget {
  const ScorecardSharePreviewScreen({
    super.key,
    required this.employeeName,
    required this.submission,
  });

  final String employeeName;
  final Submission submission;

  String get _shareText => (StringBuffer()
        ..writeln('WIGGY WASH — Scorecard')
        ..writeln(employeeName)
        ..writeln('')
        ..writeln('Memberships: ${submission.totalMemberships}')
        ..writeln('Single washes: ${submission.totalSingleWashes}')
        ..writeln('Shop sales: ${submission.totalShopSales}')
        ..writeln(
          'BA: ${submission.conversionRate.toStringAsFixed(0)}% (goal ${submission.baGoal.toStringAsFixed(0)}%)',
        )
        ..writeln(
          'Total revenue: ${_money.format(submission.grandTotalRevenue)}',
        ))
      .toString();

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Share preview'),
        actions: [
          TextButton.icon(
            onPressed: () => Share.share(_shareText),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                const Text(
                  'Preview the full card, then share or screenshot.',
                  style: TextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Transform.scale(
                  scale: 0.92,
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0x22000000),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'WIGGY WASH',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employeeName,
                            textAlign: TextAlign.center,
                            style: TextStyles.heading,
                          ),
                          const SizedBox(height: 18),
                          _row('Memberships', '${s.totalMemberships}'),
                          _row('Single washes', '${s.totalSingleWashes}'),
                          _row('Shop sales', '${s.totalShopSales}'),
                          _row(
                            'BA',
                            '${s.conversionRate.toStringAsFixed(0)}%  ·  goal ${s.baGoal.toStringAsFixed(0)}%',
                          ),
                          const Divider(height: 28),
                          Text(
                            _money.format(s.grandTotalRevenue),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total revenue',
                            textAlign: TextAlign.center,
                            style: TextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Share.share(_shareText),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share to chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyles.body)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
