import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/staff_request.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/staff_request_clear_prefs.dart';
import '../utils/staff_request_logic.dart';
import '../widgets/store_message.dart';

/// Employee: tap presets or send a custom one-liner; track status.
class EmployeeRequestsScreen extends StatefulWidget {
  const EmployeeRequestsScreen({super.key});

  @override
  State<EmployeeRequestsScreen> createState() => _EmployeeRequestsScreenState();
}

class _EmployeeRequestsScreenState extends State<EmployeeRequestsScreen> {
  final _custom = TextEditingController();
  final _lastTapByPreset = <String, DateTime>{};
  final _clearedIds = <String>{};
  bool _busy = false;
  bool _clearedLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCleared();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _loadCleared() async {
    final loc = Store.instance.activeLocationId ?? '';
    final name = Store.instance.profile?.name ?? '';
    final key = staffRequestProfileKey(name);
    final ids = await StaffRequestClearPrefs.load(
      locationId: loc,
      profileKey: key,
    );
    if (!mounted) return;
    setState(() {
      _clearedIds
        ..clear()
        ..addAll(ids);
      _clearedLoaded = true;
    });
  }

  Future<void> _clearFinished(List<StaffRequest> mine) async {
    final finished = mine
        .where((r) => r.status == StaffRequestStatus.completed)
        .map((r) => r.id)
        .toList();
    if (finished.isEmpty) return;
    final loc = Store.instance.activeLocationId ?? '';
    final name = Store.instance.profile?.name ?? '';
    final key = staffRequestProfileKey(name);
    setState(() => _busy = true);
    await StaffRequestClearPrefs.addIds(
      locationId: loc,
      profileKey: key,
      ids: finished,
    );
    if (!mounted) return;
    setState(() {
      _clearedIds.addAll(finished);
      _busy = false;
    });
    showStoreMessage(context, 'Cleared finished requests');
  }

  Future<void> _send({required String text, String? presetId}) async {
    if (presetId != null) {
      final last = _lastTapByPreset[presetId];
      final now = DateTime.now();
      if (last != null && now.difference(last) < kStaffRequestDebounce) {
        return;
      }
      _lastTapByPreset[presetId] = now;
    }
    setState(() => _busy = true);
    final err = await Store.instance.createStaffRequest(
      text: text,
      presetId: presetId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    if (presetId == null) _custom.clear();
    showStoreMessage(context, 'Request sent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Requests')),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final name = Store.instance.profile?.name ?? '';
          final key = staffRequestProfileKey(name);
          final presets = Store.instance.requestPresets;
          final mine = Store.instance.staffRequests.where((r) {
            if (r.status == StaffRequestStatus.dismissed) return false;
            if (_clearedIds.contains(r.id)) return false;
            if (r.employeeProfileKey != null &&
                r.employeeProfileKey!.isNotEmpty) {
              return r.employeeProfileKey == key;
            }
            return r.employeeName.trim().toLowerCase() == key;
          }).toList();
          final finishedCount = mine
              .where((r) => r.status == StaffRequestStatus.completed)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              const Text(
                'Quick requests',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a preset to notify your manager',
                style: TextStyles.caption,
              ),
              const SizedBox(height: 12),
              if (presets.isEmpty)
                const Text(
                  'No presets yet — ask a manager to add some, or type below.',
                  style: TextStyles.caption,
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in presets)
                      ActionChip(
                        label: Text(p.label),
                        onPressed: _busy
                            ? null
                            : () => _send(text: p.label, presetId: p.id),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
              Material(
                color: Colors.white,
                elevation: 1,
                shadowColor: const Color(0x14000000),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Custom request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _custom,
                        maxLength: kStaffRequestMaxLen,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Need more towels at bay 2',
                          isDense: true,
                        ),
                        onSubmitted: (_) {
                          if (!_busy) _send(text: _custom.text);
                        },
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed:
                            _busy ? null : () => _send(text: _custom.text),
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Your requests',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CountBadge(mine.length),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Status updates from your manager',
                          style: TextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (_clearedLoaded && finishedCount > 0)
                    TextButton(
                      onPressed: _busy ? null : () => _clearFinished(mine),
                      child: const Text('Clear finished'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E7EF)),
                ),
                child: mine.isEmpty
                    ? const _EmptyPanel(
                        icon: Icons.inbox_outlined,
                        message: 'Nothing sent yet',
                      )
                    : Column(
                        children: [
                          for (final r in mine) ...[
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      r.text,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      employeeRequestCaption(
                                        r.status,
                                        r.createdAt,
                                      ),
                                      style: TextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF2),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFC5CDD8)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
