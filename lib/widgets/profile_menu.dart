import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/store.dart';
import '../theme.dart';

/// App-bar action that opens an account sheet showing the signed-in identity,
/// role, and a sign-out button.
class ProfileAction extends StatelessWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_rounded),
      onPressed: () => _showSheet(context),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: Store.instance,
          builder: (context, _) {
            final store = Store.instance;
            final profile = store.profile;
            final acting = store.isActingAsEmployee;
            final isEmployee = store.view == AppView.employee && !acting;
            final user = store.appUser;
            final location = store.activeLocation;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Account', style: TextStyles.heading),
                  const SizedBox(height: 16),
                  _row('Name', profile?.name ?? '—'),
                  if (!isEmployee && !acting) _row('Email', user?.email ?? '—'),
                  _row('Role', profile?.role.label ?? '—'),
                  if (location != null) _row('Location', location.displayName),
                  const SizedBox(height: 20),
                  if (acting)
                    ElevatedButton.icon(
                      onPressed: () {
                        store.exitEmployeeMode();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.dashboard_rounded),
                      label: const Text('Back to dashboard'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (isEmployee) {
                          await store.signOutEmployee();
                        } else {
                          await store.signOutManager();
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(isEmployee ? 'Switch user' : 'Sign out'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyles.caption),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
