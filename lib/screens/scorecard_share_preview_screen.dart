import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/mini_scorecard_card.dart';

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

  String get _shareText {
    final s = submission;
    final buf = StringBuffer()
      ..writeln('WIGGY WASH — Scorecard')
      ..writeln(employeeName)
      ..writeln(
        'BA ${s.conversionRate.toStringAsFixed(0)}% (goal ${s.baGoal.toStringAsFixed(0)}%)',
      )
      ..writeln('');
    for (final section in Store.instance.enabledSections) {
      final lines = <String>[];
      for (final item in itemsFor(section)) {
        final c = s.countOf(item.id);
        if (c <= 0) continue;
        lines.add('${item.label}: ×$c');
      }
      if (lines.isEmpty) continue;
      buf.writeln(section.title.toUpperCase());
      for (final line in lines) {
        buf.writeln(line);
      }
      buf.writeln('');
    }
    buf.writeln('Total: ${_money.format(s.grandTotalRevenue)}');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                const Text(
                  'Preview the full card, then share or screenshot.',
                  style: TextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                MiniScorecardCard(
                  name: employeeName,
                  submissions: [submission],
                ),
                const SizedBox(height: 20),
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
}
