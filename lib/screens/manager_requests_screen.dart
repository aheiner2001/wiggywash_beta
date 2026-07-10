import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/request_preset.dart';
import '../models/staff_request.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';

final _time = DateFormat('h:mm a');

/// Manager board: Incoming → To-do → Presets for the active location.
class ManagerRequestsScreen extends StatefulWidget {
  const ManagerRequestsScreen({super.key});

  @override
  State<ManagerRequestsScreen> createState() => _ManagerRequestsScreenState();
}

class _ManagerRequestsScreenState extends State<ManagerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _presetLabel = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'To-do'),
            Tab(text: 'Presets'),
          ],
        ),
      ),
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
          return TabBarView(
            controller: _tabs,
            children: [
              _RequestList(
                empty: 'No incoming requests',
                items: incoming,
                trailing: (r) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => Store.instance.dismissStaffRequest(r.id),
                              ),
                      child: const Text('Dismiss'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => Store.instance.acceptStaffRequest(r.id),
                              ),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ),
              _RequestList(
                empty: 'No open to-dos',
                items: todos,
                trailing: (r) => ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => Store.instance.completeStaffRequest(r.id),
                          ),
                  child: const Text('Mark complete'),
                ),
              ),
              _PresetsPane(
                presets: presets,
                controller: _presetLabel,
                busy: _busy,
                onAdd: () async {
                  final label = _presetLabel.text;
                  setState(() => _busy = true);
                  final err = await Store.instance.addRequestPreset(label);
                  if (!mounted) return;
                  setState(() => _busy = false);
                  if (err != null) {
                    showStoreMessage(this.context, err, error: true);
                    return;
                  }
                  _presetLabel.clear();
                  showStoreMessage(this.context, 'Preset added');
                },
                onDelete: (id) =>
                    _run(() => Store.instance.deleteRequestPreset(id)),
                onRename: (p) async {
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
                    () => Store.instance.updateRequestPreset(
                      id: p.id,
                      label: text,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.empty,
    required this.items,
    required this.trailing,
  });

  final String empty;
  final List<StaffRequest> items;
  final Widget Function(StaffRequest r) trailing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(empty, style: TextStyles.caption));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = items[i];
        final when = r.createdAt != null ? _time.format(r.createdAt!) : '';
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(r.text, style: TextStyles.subheading),
              const SizedBox(height: 4),
              Text(
                '${r.employeeName}${when.isEmpty ? '' : ' · $when'}',
                style: TextStyles.caption,
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: trailing(r)),
            ],
          ),
        );
      },
    );
  }
}

class _PresetsPane extends StatelessWidget {
  const _PresetsPane({
    required this.presets,
    required this.controller,
    required this.busy,
    required this.onAdd,
    required this.onDelete,
    required this.onRename,
  });

  final List<RequestPreset> presets;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(RequestPreset p) onRename;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add preset', style: TextStyles.subheading),
              const SizedBox(height: 6),
              const Text(
                'Employees can tap these on their Requests screen.',
                style: TextStyles.caption,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Out of soap',
                  isDense: true,
                ),
                onSubmitted: (_) => onAdd(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: busy ? null : onAdd,
                child: const Text('Add preset'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (presets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Add presets employees can tap',
              textAlign: TextAlign.center,
              style: TextStyles.caption,
            ),
          )
        else
          for (final p in presets) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(p.label, style: TextStyles.body)),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: busy ? null : () => onRename(p),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: busy ? null : () => onDelete(p.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
