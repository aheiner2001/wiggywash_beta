import 'package:flutter/material.dart';

import '../services/store.dart';

/// Switch person / location / sign out for sticky employee sessions.
class EmployeeSessionMenu extends StatelessWidget {
  const EmployeeSessionMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      icon: const Icon(Icons.manage_accounts_outlined),
      onSelected: (value) async {
        final store = Store.instance;
        switch (value) {
          case 'person':
            await store.switchEmployeePerson();
          case 'location':
            await store.switchEmployeeLocation();
          case 'signout':
            await store.signOutEmployee();
        }
      },
      itemBuilder: (context) {
        final multi =
            Store.instance.companyLocations.length > 1 ||
            Store.instance.activeCompanyId != null;
        return [
          const PopupMenuItem(
            value: 'person',
            child: Text('Switch person'),
          ),
          if (multi)
            const PopupMenuItem(
              value: 'location',
              child: Text('Switch location'),
            ),
          const PopupMenuItem(
            value: 'signout',
            child: Text('Sign out'),
          ),
        ];
      },
    );
  }
}
