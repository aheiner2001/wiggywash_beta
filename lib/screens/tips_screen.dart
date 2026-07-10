import 'package:flutter/material.dart';

import '../theme.dart';

enum TipsAudience { employee, manager }

/// Short how-to tips for employees and managers (replaces breakdown HelpScreen).
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key, this.audience = TipsAudience.employee});

  final TipsAudience audience;

  bool get _isManager => audience == TipsAudience.manager;

  @override
  Widget build(BuildContext context) {
    final tips = _isManager ? _managerTips : _employeeTips;
    return Scaffold(
      appBar: AppBar(title: Text(_isManager ? 'Manager tips' : 'Tips')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                      child: const Icon(Icons.lightbulb_outline_rounded,
                          color: AppColors.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isManager
                            ? 'Quick guide to the manager tabs and sharing access with your team.'
                            : 'Quick guide to signing in and submitting your scorecard.',
                        style: TextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < tips.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _TipCard(
                  number: i + 1,
                  title: tips[i].title,
                  body: tips[i].body,
                  icon: tips[i].icon,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip {
  const _Tip(this.title, this.body, this.icon);
  final String title;
  final String body;
  final IconData icon;
}

const _employeeTips = [
  _Tip(
    'Sign in',
    'Enter your company code, pick your location, then your name. Enter your PIN if asked.',
    Icons.login_rounded,
  ),
  _Tip(
    'Tally and submit',
    'Count memberships, washes, and shop sales, then tap Submit Shift when you are done.',
    Icons.fact_check_outlined,
  ),
  _Tip(
    'Save as you go',
    'Tap Save during your shift so totals stay on the sticky bar and in the database. Submit Shift when you are finished.',
    Icons.save_outlined,
  ),
  _Tip(
    'Sharing a device',
    'Use Switch user in the profile menu so the next person can sign in as themselves.',
    Icons.people_outline_rounded,
  ),
];

const _managerTips = [
  _Tip(
    'Dashboard',
    'Live team totals, pending approvals, and challenges for the active location.',
    Icons.dashboard_rounded,
  ),
  _Tip(
    'Master Sheet',
    'History grid, export (Excel/CSV), and trends/stats for the selected period.',
    Icons.table_chart_outlined,
  ),
  _Tip(
    'Team',
    'Roster, company code for employees, and switch or add locations.',
    Icons.group_outlined,
  ),
  _Tip(
    'Prices',
    'Set membership, wash, and shop prices used on scorecards and totals.',
    Icons.sell_outlined,
  ),
  _Tip(
    'Employee access',
    'Share your company code (shown on Team). Employees do not sign in with Google.',
    Icons.qr_code_2_rounded,
  ),
];

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });

  final int number;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.navy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title, style: TextStyles.subheading),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
