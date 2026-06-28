import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/worker.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';

/// Manager screen: the location's **site code** (shared with employees) plus the
/// **name roster** employees pick from after entering that code.
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

  Future<void> _shareSiteCode() async {
    final loc = Store.instance.activeLocation;
    if (loc == null) return;
    if (loc.siteCode.isEmpty) {
      showStoreMessage(context, 'Set a site code first.', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _SiteCodeShareCard(
          locationName: loc.displayName,
          code: loc.siteCode,
          onShare: () {
            final text = 'Sign in to the Wiggy Wash scorecard for '
                '${loc.displayName}.\nSite code: ${loc.siteCode}';
            Share.share(text);
          },
        ),
      ),
    );
  }

  Future<void> _editSiteCode() async {
    final loc = Store.instance.activeLocation;
    if (loc == null) return;
    final controller = TextEditingController(text: loc.siteCode);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Site code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Site code',
            hintText: 'e.g. OMAHA1',
          ),
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
    );
    final value = controller.text;
    controller.dispose();
    if (saved != true || !mounted) return;
    final err = await Store.instance.setSiteCode(loc.id, value);
    if (!mounted) return;
    showStoreMessage(context, err ?? 'Site code updated', error: err != null);
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
        title: const Text('Team & Site Code'),
        actions: [
          IconButton(
            tooltip: 'Share site code',
            onPressed: _shareSiteCode,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final workers = Store.instance.workers;
          final code = Store.instance.activeLocation?.siteCode ?? '';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SiteCodeCard(code: code, onEdit: _editSiteCode),
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
                          'enter the site code.',
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

class _SiteCodeCard extends StatelessWidget {
  const _SiteCodeCard({required this.code, required this.onEdit});
  final String code;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onEdit,
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Site code', style: TextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  code.isEmpty ? 'Not set — tap to add' : code,
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
          const Icon(Icons.edit_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// A clean, screenshot-friendly card a manager can show staff: big site code,
/// location name, and a Share button.
class _SiteCodeShareCard extends StatelessWidget {
  const _SiteCodeShareCard({
    required this.locationName,
    required this.code,
    required this.onShare,
  });

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
            'SITE CODE',
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
            locationName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open the app, enter this code, then pick your name.',
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
