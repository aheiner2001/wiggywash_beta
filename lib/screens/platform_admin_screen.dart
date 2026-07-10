import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/company.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/profile_menu.dart';
import '../widgets/managers_section.dart';
import '../widgets/status_badge.dart';
import '../widgets/store_message.dart';
import 'manager_screen.dart';

final _dateFmt = DateFormat('MMM d, yyyy');

enum _CompanyFilter { pending, active, all }

/// Platform operator console — approve new company signups and manage tenants.
class PlatformAdminScreen extends StatefulWidget {
  const PlatformAdminScreen({super.key});

  @override
  State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
  _CompanyFilter _filter = _CompanyFilter.pending;

  List<Company> get _filtered {
    final all = Store.instance.companies;
    return switch (_filter) {
      _CompanyFilter.pending =>
        all.where((c) => c.status == CompanyStatus.pending).toList(),
      _CompanyFilter.active =>
        all.where((c) => c.status == CompanyStatus.active).toList(),
      _CompanyFilter.all => all,
    };
  }

  Future<void> _migrate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrate to company tenant?'),
        content: const Text(
          'Creates companies/wiggy-wash and copies every root location '
          '(with submissions, roster, config) underneath it. Safe to run once.',
        ),
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
    if (ok != true || !mounted) return;
    final err = await Store.instance.migrateToCompany(
      companyId: 'wiggy-wash',
      companyName: 'Wiggy Wash',
      companyCode: 'WIGGY',
    );
    if (!mounted) return;
    showStoreMessage(
      context,
      err ?? 'Wiggy Wash migrated — employees can use code WIGGY',
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin'),
        actions: [
          IconButton(
            tooltip: 'Migrate legacy data',
            onPressed: _migrate,
            icon: const Icon(Icons.cloud_upload_rounded),
          ),
          const ProfileAction(),
        ],
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final companies = _filtered;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: SegmentedButton<_CompanyFilter>(
                      segments: const [
                        ButtonSegment(
                            value: _CompanyFilter.pending,
                            label: Text('Pending')),
                        ButtonSegment(
                            value: _CompanyFilter.active,
                            label: Text('Active')),
                        ButtonSegment(
                            value: _CompanyFilter.all, label: Text('All')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) =>
                          setState(() => _filter = s.first),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      children: [
                        if (companies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Text(
                              'No companies in this view.',
                              textAlign: TextAlign.center,
                              style: TextStyles.caption,
                            ),
                          )
                        else
                          ...companies.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CompanyCard(company: c),
                            ),
                          ),
                      ],
                    ),
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

class _CompanyCard extends StatefulWidget {
  const _CompanyCard({required this.company});
  final Company company;

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  int _locationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final n =
        await Store.instance.locationCountForCompany(widget.company.id);
    if (mounted) setState(() => _locationCount = n);
  }

  Future<void> _approve() async {
    final err = await Store.instance.approveCompany(widget.company.id);
    if (!mounted) return;
    showStoreMessage(
      context,
      err ?? 'Approved ${widget.company.name}',
      error: err != null,
    );
  }

  Future<void> _reject() async {
    final reason = TextEditingController();
    final result = await showDialog<({bool ok, String reason})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject company?'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Why this signup was not approved',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, (ok: false, reason: '')),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () =>
                Navigator.pop(ctx, (ok: true, reason: reason.text)),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (result == null || !result.ok) return;
    final err = await Store.instance.rejectCompany(
      widget.company.id,
      reason: result.reason,
    );
    if (!mounted) return;
    showStoreMessage(context, err ?? 'Rejected', error: err != null);
  }

  Future<void> _toggleSuspend(bool active) async {
    final err = await Store.instance.setCompanyActive(
      widget.company.id,
      active,
    );
    if (!mounted) return;
    showStoreMessage(context, err ?? 'Updated', error: err != null);
  }

  Future<void> _view() async {
    await Store.instance.openCompanyAsAdmin(widget.company.id);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManagerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.company;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusBadge(status: c.status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(c.name, style: TextStyles.subheading),
              ),
              Text(c.companyCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (c.createdByEmail != null && c.createdByEmail!.isNotEmpty)
                c.createdByEmail!,
              if (c.createdAt != null) _dateFmt.format(c.createdAt!),
              '$_locationCount location${_locationCount == 1 ? '' : 's'}',
            ].join(' · '),
            style: TextStyles.caption,
          ),
          if (c.rejectionReason != null && c.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reason: ${c.rejectionReason}', style: TextStyles.caption),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (c.status == CompanyStatus.pending) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _reject,
                  child: const Text('Reject'),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _view,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                if (c.status == CompanyStatus.active)
                  OutlinedButton(
                    onPressed: () => _toggleSuspend(false),
                    child: const Text('Suspend'),
                  )
                else if (c.status == CompanyStatus.suspended)
                  OutlinedButton(
                    onPressed: () => _toggleSuspend(true),
                    child: const Text('Reactivate'),
                  ),
              ],
            ],
          ),
          if (c.status == CompanyStatus.active ||
              c.status == CompanyStatus.pending) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Managers', style: TextStyles.subheading),
              children: [
                ManagersSection(companyId: c.id),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
