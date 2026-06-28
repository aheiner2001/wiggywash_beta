import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/profile_menu.dart';
import '../widgets/store_message.dart';
import 'manager_screen.dart';

/// Top-level console: create/disable locations, open any location's dashboard,
/// and run the one-time legacy-data migration.
class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  Future<void> _createLocation(BuildContext context) async {
    final name = TextEditingController();
    final city = TextEditingController();
    final siteCode = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: siteCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Site code (employees sign in with this)',
                hintText: 'e.g. OMAHA1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    final id = await Store.instance
        .createLocation(name.text, city: city.text, siteCode: siteCode.text);
    if (!context.mounted) return;
    showStoreMessage(context, id == null ? 'Could not create location' : 'Location created',
        error: id == null);
  }

  Future<void> _openDashboard(BuildContext context, Location loc) async {
    await Store.instance.setActiveLocation(loc.id);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManagerScreen()),
    );
  }

  Future<void> _migrate(BuildContext context, Location loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrate legacy data?'),
        content: Text(
            'Copy the old top-level submissions, roster, prices, and settings '
            'into "${loc.displayName}". Safe to run once after upgrading.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Migrate')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Store.instance.migrateLegacyDataToLocation(loc.id);
    if (!context.mounted) return;
    showStoreMessage(context, err ?? 'Migration complete', error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: const [ProfileAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createLocation(context),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add location'),
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final locations = Store.instance.locations;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                children: [
                  const Text(
                    'Locations',
                    style: TextStyles.heading,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Each location has its own roster, prices, and submissions. '
                    'Managers join a location with the master code.',
                    style: TextStyles.caption,
                  ),
                  const SizedBox(height: 12),
                  if (locations.isEmpty)
                    const AppCard(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No locations yet. Tap "Add location" to create your '
                        'first pilot site.',
                        textAlign: TextAlign.center,
                        style: TextStyles.caption,
                      ),
                    )
                  else
                    ...locations.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LocationCard(
                            location: l,
                            onOpen: () => _openDashboard(context, l),
                            onMigrate: () => _migrate(context, l),
                          ),
                        )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onOpen,
    required this.onMigrate,
  });

  final Location location;
  final VoidCallback onOpen;
  final VoidCallback onMigrate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.store_mall_directory_rounded,
                  color: AppColors.navy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location.displayName, style: TextStyles.subheading),
                    Text(
                      '${location.active ? 'Active' : 'Disabled'} · '
                      'Code: ${location.siteCode.isEmpty ? '—' : location.siteCode}',
                      style: TextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: location.active,
                onChanged: (v) async {
                  final err =
                      await Store.instance.setLocationActive(location.id, v);
                  if (context.mounted && err != null) {
                    showStoreMessage(context, err, error: true);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.dashboard_rounded, size: 18),
                  label: const Text('Open dashboard'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Migrate legacy data',
                onPressed: onMigrate,
                icon: const Icon(Icons.move_to_inbox_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
