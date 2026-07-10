import 'package:flutter/material.dart';

import '../screens/billing_screen.dart';
import '../screens/manager_screen.dart';
import '../screens/manager_requests_screen.dart';
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
    (icon: Icons.campaign_outlined, label: 'Requests'),
    (icon: Icons.group_outlined, label: 'Team'),
    (icon: Icons.sell_outlined, label: 'Prices'),
    (icon: Icons.payments_outlined, label: 'Billing'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  static const _mobileLabels = [
    'Home',
    'Sheet',
    'Requests',
    'Team',
    'Prices',
    'Billing',
    'Settings',
  ];

  Widget _page(int index) => switch (index) {
        0 => const ManagerScreen(),
        1 => const MasterSheetScreen(),
        2 => const ManagerRequestsScreen(),
        3 => const TeamScreen(),
        4 => const PricingScreen(),
        5 => const BillingScreen(),
        6 => const SettingsScreen(),
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

  Widget _requestsIcon({required bool selected}) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final n = Store.instance.pendingStaffRequestCount;
        final icon = Icon(
          selected ? Icons.campaign_rounded : Icons.campaign_outlined,
        );
        return Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          child: icon,
        );
      },
    );
  }

  Widget _destIcon(int i, {required bool selected}) {
    if (i == 1) return _sheetIcon(selected: selected);
    if (i == 2) return _requestsIcon(selected: selected);
    return Icon(_destinations[i].icon);
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
                        icon: _destIcon(i, selected: false),
                        selectedIcon: _destIcon(i, selected: true),
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
                    icon: _destIcon(i, selected: false),
                    selectedIcon: _destIcon(i, selected: true),
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
