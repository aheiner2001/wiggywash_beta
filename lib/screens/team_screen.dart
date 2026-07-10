import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/worker.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/managers_section.dart';
import '../widgets/store_message.dart';

/// Manager screen: company code for employees plus roster and locations.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  bool _usePin = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final err = await Store.instance.addWorker(
      _name.text,
      pin: _usePin ? _pin.text : null,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      showStoreMessage(context, err, error: true);
      return;
    }
    _name.clear();
    _pin.clear();
    setState(() {
      _error = null;
      _usePin = false;
    });
    showStoreMessage(context, 'Added to roster');
  }

  Future<void> _shareCompanyCode() async {
    final company = Store.instance.activeCompany;
    if (company == null || company.companyCode.isEmpty) {
      showStoreMessage(context, 'Company code not available yet.', error: true);
      return;
    }
    final loc = Store.instance.activeLocation;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _CompanyCodeShareCard(
          companyName: company.name,
          locationName: loc?.displayName ?? company.name,
          code: company.companyCode,
          onShare: () {
            Share.share(
              'Sign in to the ${company.name} scorecard.\n'
              'Company code: ${company.companyCode}',
            );
          },
        ),
      ),
    );
  }

  Future<void> _addLocation() async {
    final name = TextEditingController();
    final city = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Location name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      name.dispose();
      city.dispose();
      return;
    }
    final id = await Store.instance.createLocation(name.text, city: city.text);
    name.dispose();
    city.dispose();
    if (!mounted) return;
    if (id == null) {
      showStoreMessage(context, 'Could not add location.', error: true);
      return;
    }
    await Store.instance.setActiveLocation(id);
    final companyId = Store.instance.activeCompanyId;
    if (companyId != null) {
      await Store.instance.previewCompany(companyId);
    }
    if (!mounted) return;
    showStoreMessage(context, 'Location added');
  }

  Future<void> _remove(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove worker?'),
        content: Text(
          'Remove $name from the team list? Their past scorecards stay in history.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await Store.instance.removeWorker(id);
    if (!mounted) return;
    showStoreMessage(context, err ?? '$name removed', error: err != null);
  }

  Future<void> _editWorker(String id, String name, String? currentPin) async {
    final pinController = TextEditingController(text: currentPin ?? '');
    var requirePin = currentPin != null && currentPin.isNotEmpty;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require entry code'),
                subtitle: const Text('Employee must type this code to sign in'),
                value: requirePin,
                onChanged: (v) => setDialog(() => requirePin = v),
              ),
              if (requirePin)
                TextField(
                  controller: pinController,
                  decoration: const InputDecoration(
                    labelText: 'Entry code',
                    hintText: 'Enter code',
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
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) {
      pinController.dispose();
      return;
    }
    final err = await Store.instance.updateWorker(
      id,
      pin: requirePin ? pinController.text : null,
      clearPin: !requirePin,
    );
    pinController.dispose();
    if (!mounted) return;
    showStoreMessage(context, err ?? 'Updated $name', error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            tooltip: 'Share company code',
            onPressed: _shareCompanyCode,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Add location',
            onPressed: _addLocation,
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final workers = Store.instance.workers;
          final company = Store.instance.activeCompany;
          final code = company?.companyCode ?? '';
          final locations = Store.instance.companyLocations.isNotEmpty
              ? Store.instance.companyLocations
              : Store.instance.locations;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CompanyCodeCard(code: code, companyName: company?.name),
                  if (company != null) ...[
                    const SizedBox(height: 16),
                    ManagersSection(companyId: company.id),
                  ],
                  if (locations.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(Store.instance.activeLocationId),
                      initialValue: Store.instance.activeLocationId,
                      decoration: const InputDecoration(
                        labelText: 'Active location',
                        isDense: true,
                      ),
                      items: [
                        for (final l in locations)
                          DropdownMenuItem(value: l.id, child: Text(l.displayName)),
                      ],
                      onChanged: (id) {
                        if (id != null) Store.instance.setActiveLocation(id);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Add a worker', style: TextStyles.subheading),
                        const SizedBox(height: 8),
                        const Text(
                          'Employees pick their name from this list after they '
                          'enter the company code.',
                          style: TextStyles.caption,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Enter name',
                            errorText: _error,
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _add(),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Require entry code'),
                          subtitle: const Text('Optional short code to sign in'),
                          value: _usePin,
                          onChanged: (v) => setState(() => _usePin = v),
                        ),
                        if (_usePin)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _pin,
                              decoration: const InputDecoration(
                                labelText: 'Entry code',
                                hintText: 'Enter code',
                              ),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('Add to roster'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (workers.isEmpty)
                    const AppCard(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No workers yet. Add names above — employees choose from '
                        'this list.',
                        textAlign: TextAlign.center,
                        style: TextStyles.caption,
                      ),
                    )
                  else
                    _RosterList(
                      workers: workers,
                      onEdit: _editWorker,
                      onRemove: _remove,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompanyCodeCard extends StatelessWidget {
  const _CompanyCodeCard({required this.code, this.companyName});
  final String code;
  final String? companyName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName ?? 'Company code',
                  style: TextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  code.isEmpty ? 'Pending approval' : code,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: code.isEmpty ? AppColors.textMuted : AppColors.navy,
                  ),
                ),
                const Text('Employees type this to sign in',
                    style: TextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyCodeShareCard extends StatelessWidget {
  const _CompanyCodeShareCard({
    required this.companyName,
    required this.locationName,
    required this.code,
    required this.onShare,
  });

  final String companyName;
  final String locationName;
  final String code;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/logo.png', height: 64, fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const SizedBox.shrink()),
          const SizedBox(height: 20),
          const Text(
            'COMPANY CODE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            companyName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            locationName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open the app, enter this code, pick a location, then your name.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.navy,
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.workers,
    required this.onEdit,
    required this.onRemove,
  });

  final List<Worker> workers;
  final void Function(String id, String name, String? pin) onEdit;
  final void Function(String id, String name) onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child:
                Text('${workers.length} on roster', style: TextStyles.caption),
          ),
          for (final w in workers)
            ListTile(
              onTap: () => onEdit(w.id, w.name, w.pin),
              leading: CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Text(
                  w.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              title: Text(w.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: w.requiresPin
                  ? const Text('Entry code required', style: TextStyles.caption)
                  : null,
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                color: AppColors.danger,
                onPressed: () => onRemove(w.id, w.name),
              ),
            ),
        ],
      ),
    );
  }
}
