import 'package:flutter/material.dart';

import '../screens/manager_screen.dart';
import '../screens/master_sheet_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/team_screen.dart';
import '../services/store.dart';

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
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  static const _mobileLabels = [
    'Home',
    'Sheet',
    'Team',
    'Prices',
    'Settings',
  ];

  Widget _page(int index) => switch (index) {
        0 => const ManagerScreen(),
        1 => const MasterSheetScreen(),
        2 => const TeamScreen(),
        3 => const PricingScreen(),
        4 => const SettingsScreen(),
        _ => const ManagerScreen(),
      };

  Widget _sheetIcon({required bool selected}) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final pending = Store.instance.pendingSubmissions.length;
        final icon = Icon(
          selected ? Icons.table_chart_rounded : Icons.table_chart_outlined,
        );
        return Badge(
          isLabelVisible: pending > 0,
          label: Text('$pending'),
          child: icon,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final body = KeyedSubtree(
      key: ValueKey<int>(_index),
      child: _page(_index),
    );
    final animatedBody = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: body,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: primary.withValues(alpha: 0.08),
                  indicatorColor: primary.withValues(alpha: 0.18),
                  selectedIconTheme: IconThemeData(color: primary),
                  selectedLabelTextStyle: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                  destinations: [
                    for (var i = 0; i < _destinations.length; i++)
                      NavigationRailDestination(
                        icon: i == 1
                            ? _sheetIcon(selected: false)
                            : Icon(_destinations[i].icon),
                        selectedIcon: i == 1
                            ? _sheetIcon(selected: true)
                            : Icon(_destinations[i].icon),
                        label: Text(_destinations[i].label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: animatedBody),
              ],
            ),
          );
        }
        return Scaffold(
          body: animatedBody,
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 68,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.1,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationDestination(
                    icon: i == 1
                        ? _sheetIcon(selected: false)
                        : Icon(_destinations[i].icon),
                    selectedIcon: i == 1
                        ? _sheetIcon(selected: true)
                        : Icon(_destinations[i].icon),
                    label: _mobileLabels[i],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
