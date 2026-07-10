import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/request_preset.dart';
import '../models/staff_request.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';

final _time = DateFormat('h:mm a');

/// Manager board: one page with Incoming, To-do, and Presets sections.
class ManagerRequestsScreen extends StatefulWidget {
  const ManagerRequestsScreen({super.key});

  @override
  State<ManagerRequestsScreen> createState() => _ManagerRequestsScreenState();
}

class _ManagerRequestsScreenState extends State<ManagerRequestsScreen> {
  final _presetLabel = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _presetLabel.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action, {String? ok}) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
    } else if (ok != null) {
      showStoreMessage(context, ok);
    }
  }

  Future<void> _renamePreset(RequestPreset p) async {
    final c = TextEditingController(text: p.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit preset'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Label'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = c.text;
    c.dispose();
    if (ok != true || !mounted) return;
    await _run(
      () => Store.instance.updateRequestPreset(id: p.id, label: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final all = Store.instance.staffRequests;
          final incoming = all
              .where((r) => r.status == StaffRequestStatus.pending)
              .toList();
          final todos = all
              .where((r) => r.status == StaffRequestStatus.accepted)
              .toList();
          final presets = Store.instance.requestPresets;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _SectionHeader(
                title: 'Incoming',
                subtitle: 'New asks from the floor',
                count: incoming.length,
              ),
              const SizedBox(height: 10),
              if (incoming.isEmpty)
                const _EmptyCard('No incoming requests')
              else
                for (final r in incoming) ...[
                  _RequestCard(
                    request: r,
                    actions: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () =>
                                      Store.instance.dismissStaffRequest(r.id),
                                ),
                        child: const Text('Dismiss'),
                      ),
                      ElevatedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () =>
                                      Store.instance.acceptStaffRequest(r.id),
                                  ok: 'Added to to-do',
                                ),
                        child: const Text('Add to to-do'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'To-do',
                subtitle: 'Accepted — finish these',
                count: todos.length,
              ),
              const SizedBox(height: 10),
              if (todos.isEmpty)
                const _EmptyCard('No open to-dos')
              else
                for (final r in todos) ...[
                  _RequestCard(
                    request: r,
                    actions: [
                      ElevatedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => Store.instance
                                      .completeStaffRequest(r.id),
                                  ok: 'Marked complete',
                                ),
                        child: const Text('Mark complete'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Presets',
                subtitle: 'Chips employees can tap',
                count: presets.length,
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _presetLabel,
                      decoration: const InputDecoration(
                        labelText: 'New preset label',
                        hintText: 'Out of soap',
                        isDense: true,
                      ),
                      onSubmitted: (_) async {
                        final label = _presetLabel.text;
                        setState(() => _busy = true);
                        final err =
                            await Store.instance.addRequestPreset(label);
                        if (!mounted) return;
                        setState(() => _busy = false);
                        if (err != null) {
                          showStoreMessage(context, err, error: true);
                          return;
                        }
                        _presetLabel.clear();
                        showStoreMessage(context, 'Preset added');
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final label = _presetLabel.text;
                              setState(() => _busy = true);
                              final err = await Store.instance
                                  .addRequestPreset(label);
                              if (!mounted) return;
                              setState(() => _busy = false);
                              if (err != null) {
                                showStoreMessage(context, err, error: true);
                                return;
                              }
                              _presetLabel.clear();
                              showStoreMessage(context, 'Preset added');
                            },
                      child: const Text('Add preset'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (presets.isEmpty)
                const _EmptyCard('Add presets employees can tap')
              else
                for (final p in presets) ...[
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.label, style: TextStyles.body)),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: _busy ? null : () => _renamePreset(p),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: _busy
                              ? null
                              : () => _run(
                                    () => Store.instance
                                        .deleteRequestPreset(p.id),
                                  ),
                          icon: const Icon(Icons.delete_outline),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyles.subheading),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyles.caption),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyles.caption,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.actions});

  final StaffRequest request;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final when =
        request.createdAt != null ? _time.format(request.createdAt!) : '';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(request.text, style: TextStyles.subheading),
          const SizedBox(height: 4),
          Text(
            '${request.employeeName}${when.isEmpty ? '' : ' · $when'}',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }
}
