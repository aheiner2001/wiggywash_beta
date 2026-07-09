import 'package:flutter/material.dart';

import '../screens/manager_screen.dart';
import '../screens/master_sheet_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/team_screen.dart';
import '../theme.dart';

/// Manager navigation — sidebar on desktop, bottom bar on mobile.
class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.table_chart_outlined, label: 'Master Sheet'),
    (icon: Icons.group_outlined, label: 'Team'),
    (icon: Icons.sell_outlined, label: 'Prices'),
  ];

  Widget _page(int index) => switch (index) {
        0 => const ManagerScreen(),
        1 => const MasterSheetScreen(),
        2 => const TeamScreen(),
        3 => const PricingScreen(),
        _ => const ManagerScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = _page(_index);
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.blueSoft,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in _destinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        );
      },
    );
  }
}
