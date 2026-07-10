import 'package:flutter/material.dart';

import '../models/manager_invite.dart';
import '../services/store.dart';
import '../theme.dart';
import 'store_message.dart';

/// Shared Managers list for Team and Platform Admin.
class ManagersSection extends StatefulWidget {
  const ManagersSection({super.key, required this.companyId});
  final String companyId;

  @override
  State<ManagersSection> createState() => _ManagersSectionState();
}

class _ManagersSectionState extends State<ManagersSection> {
  List<ManagerInvite> _invites = [];
  bool _loading = true;
  final _email = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ManagersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _reload();
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await Store.instance.listManagerInvites(widget.companyId);
    if (!mounted) return;
    setState(() {
      _invites = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    final err = await Store.instance.addManagerInvite(
      companyId: widget.companyId,
      email: _email.text,
      displayName: _name.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    _email.clear();
    _name.clear();
    showStoreMessage(
      context,
      'Invite saved — they must sign in with that Google email.',
    );
    await _reload();
  }

  Future<void> _editName(ManagerInvite invite) async {
    final controller = TextEditingController(text: invite.displayName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name (optional)'),
          textCapitalization: TextCapitalization.words,
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
    final text = controller.text;
    controller.dispose();
    if (ok != true || !mounted) return;
    final err = await Store.instance.updateManagerInviteDisplayName(
      companyId: widget.companyId,
      inviteId: invite.id,
      displayName: text,
    );
    if (!mounted) return;
    showStoreMessage(context, err ?? 'Updated', error: err != null);
    await _reload();
  }

  Future<void> _remove(ManagerInvite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove manager?'),
        content: Text(
          'Remove ${invite.email}? They will lose dashboard access.',
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
    final err = await Store.instance.removeManagerInvite(
      companyId: widget.companyId,
      inviteId: invite.id,
    );
    if (!mounted) return;
    showStoreMessage(context, err ?? 'Removed', error: err != null);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Managers', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            'They must Continue with Google using this exact address.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_invites.isEmpty)
            const Text('No managers yet.', style: TextStyles.caption)
          else
            for (final inv in _invites)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(inv.email,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (inv.displayName != null && inv.displayName!.isNotEmpty)
                      inv.displayName!,
                    inv.isClaimed ? 'Signed in' : 'Invited',
                  ].join(' · '),
                  style: TextStyles.caption,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit name',
                      onPressed: () => _editName(inv),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => _remove(inv),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Google email',
              hintText: 'name@gmail.com',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _add,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Add manager'),
          ),
        ],
      ),
    );
  }
}
