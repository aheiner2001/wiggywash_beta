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
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Quick requests', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap a preset to notify your manager.',
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
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in presets)
                            ActionChip(
                              label: Text(p.label),
                              onPressed: _busy
                                  ? null
                                  : () => _send(
                                        text: p.label,
                                        presetId: p.id,
                                      ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Custom request', style: TextStyles.subheading),
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
                        if (!_busy) {
                          _send(text: _custom.text);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed:
                          _busy ? null : () => _send(text: _custom.text),
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Your requests', style: TextStyles.subheading),
                  ),
                  if (_clearedLoaded && finishedCount > 0)
                    TextButton(
                      onPressed: _busy ? null : () => _clearFinished(mine),
                      child: const Text('Clear finished'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nothing sent yet',
                    textAlign: TextAlign.center,
                    style: TextStyles.caption,
                  ),
                )
              else
                for (final r in mine) ...[
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.text, style: TextStyles.body),
                              const SizedBox(height: 4),
                              Text(
                                r.status.employeeLabel,
                                style: TextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}
