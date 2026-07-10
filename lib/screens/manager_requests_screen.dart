import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/request_preset.dart';
import '../models/staff_request.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';

final _time = DateFormat('h:mm a');

enum _IncomingSort { newest, name }

/// Manager Requests board styled as a two-column dashboard + presets strip.
class ManagerRequestsScreen extends StatefulWidget {
  const ManagerRequestsScreen({super.key});

  @override
  State<ManagerRequestsScreen> createState() => _ManagerRequestsScreenState();
}

class _ManagerRequestsScreenState extends State<ManagerRequestsScreen> {
  final _presetLabel = TextEditingController();
  final _presetFocus = FocusNode();
  final _presetsKey = GlobalKey();
  bool _busy = false;
  bool _showAllPresets = false;
  _IncomingSort _sort = _IncomingSort.newest;

  @override
  void dispose() {
    _presetLabel.dispose();
    _presetFocus.dispose();
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

  Future<void> _addPresetFromField() async {
    final label = _presetLabel.text;
    setState(() => _busy = true);
    final err = await Store.instance.addRequestPreset(label);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    _presetLabel.clear();
    showStoreMessage(context, 'Preset added');
  }

  Future<void> _openAddPresetDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Request'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Preset label',
            hintText: 'Out of soap',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add preset'),
          ),
        ],
      ),
    );
    final text = c.text;
    c.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final err = await Store.instance.addRequestPreset(text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    showStoreMessage(context, 'Preset added');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _presetsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
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

  List<StaffRequest> _sortedIncoming(List<StaffRequest> items) {
    final copy = [...items];
    switch (_sort) {
      case _IncomingSort.newest:
        copy.sort((a, b) {
          final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
      case _IncomingSort.name:
        copy.sort(
          (a, b) => a.employeeName.toLowerCase().compareTo(
                b.employeeName.toLowerCase(),
              ),
        );
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Requests'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _busy ? null : _openAddPresetDialog,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add New Request',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final all = Store.instance.staffRequests;
          final incoming = _sortedIncoming(
            all
                .where((r) => r.status == StaffRequestStatus.pending)
                .toList(),
          );
          final todos = all
              .where((r) => r.status == StaffRequestStatus.accepted)
              .toList();
          final presets = Store.instance.requestPresets;
          final visiblePresets =
              _showAllPresets ? presets : presets.take(6).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 28 : 16,
                  20,
                  wide ? 28 : 16,
                  40,
                ),
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BoardColumn(
                            title: 'Incoming',
                            subtitle: 'New asks from the floor',
                            count: incoming.length,
                            trailingHeader: _SortFilterButton(
                              sort: _sort,
                              onChanged: (s) => setState(() => _sort = s),
                            ),
                            child: incoming.isEmpty
                                ? const _EmptyPanel(
                                    icon: Icons.inbox_outlined,
                                    message: 'No incoming requests',
                                  )
                                : Column(
                                    children: [
                                      for (final r in incoming) ...[
                                        _RequestTile(
                                          request: r,
                                          actions: _incomingActions(r),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _BoardColumn(
                            title: 'To-do',
                            subtitle: 'Accepted — finish these',
                            count: todos.length,
                            child: todos.isEmpty
                                ? const _EmptyPanel(
                                    icon: Icons.checklist_rtl_rounded,
                                    message: 'No open to-dos',
                                  )
                                : Column(
                                    children: [
                                      for (final r in todos) ...[
                                        _RequestTile(
                                          request: r,
                                          actions: _todoActions(r),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _BoardColumn(
                      title: 'Incoming',
                      subtitle: 'New asks from the floor',
                      count: incoming.length,
                      trailingHeader: _SortFilterButton(
                        sort: _sort,
                        onChanged: (s) => setState(() => _sort = s),
                      ),
                      child: incoming.isEmpty
                          ? const _EmptyPanel(
                              icon: Icons.inbox_outlined,
                              message: 'No incoming requests',
                            )
                          : Column(
                              children: [
                                for (final r in incoming) ...[
                                  _RequestTile(
                                    request: r,
                                    actions: _incomingActions(r),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    _BoardColumn(
                      title: 'To-do',
                      subtitle: 'Accepted — finish these',
                      count: todos.length,
                      child: todos.isEmpty
                          ? const _EmptyPanel(
                              icon: Icons.checklist_rtl_rounded,
                              message: 'No open to-dos',
                            )
                          : Column(
                              children: [
                                for (final r in todos) ...[
                                  _RequestTile(
                                    request: r,
                                    actions: _todoActions(r),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  KeyedSubtree(
                    key: _presetsKey,
                    child: _PresetsSection(
                      count: presets.length,
                      controller: _presetLabel,
                      focusNode: _presetFocus,
                      busy: _busy,
                      presets: visiblePresets,
                      showSeeAll: presets.length > 6 && !_showAllPresets,
                      onSeeAll: () => setState(() => _showAllPresets = true),
                      onAdd: _busy ? null : _addPresetFromField,
                      onRename: _busy ? null : _renamePreset,
                      onDelete: _busy
                          ? null
                          : (id) => _run(
                                () => Store.instance.deleteRequestPreset(id),
                              ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _incomingActions(StaffRequest r) => [
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() => Store.instance.dismissStaffRequest(r.id)),
          child: const Text('Dismiss'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                    () => Store.instance.acceptStaffRequest(r.id),
                    ok: 'Added to to-do',
                  ),
          child: const Text('Add to to-do'),
        ),
      ];

  List<Widget> _todoActions(StaffRequest r) => [
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                    () => Store.instance.completeStaffRequest(r.id),
                    ok: 'Marked complete',
                  ),
          child: const Text('Mark complete'),
        ),
      ];
}

class _SortFilterButton extends StatelessWidget {
  const _SortFilterButton({required this.sort, required this.onChanged});

  final _IncomingSort sort;
  final ValueChanged<_IncomingSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_IncomingSort>(
      initialValue: sort,
      onSelected: onChanged,
      tooltip: 'Sort / Filter',
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _IncomingSort.newest,
          child: Text('Newest first'),
        ),
        PopupMenuItem(
          value: _IncomingSort.name,
          child: Text('By name'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8DEE8)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort / Filter',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.child,
    this.trailingHeader,
  });

  final String title;
  final String subtitle;
  final int count;
  final Widget child;
  final Widget? trailingHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountBadge(count),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyles.caption),
                ],
              ),
            ),
            ?trailingHeader,
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 240),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E7EF)),
          ),
          child: child,
        ),
      ],
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

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.actions});

  final StaffRequest request;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final when =
        request.createdAt != null ? _time.format(request.createdAt!) : '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
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
      ),
    );
  }
}

class _PresetsSection extends StatelessWidget {
  const _PresetsSection({
    required this.count,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.presets,
    required this.showSeeAll,
    required this.onSeeAll,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
  });

  final int count;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final List<RequestPreset> presets;
  final bool showSeeAll;
  final VoidCallback onSeeAll;
  final VoidCallback? onAdd;
  final Future<void> Function(RequestPreset p)? onRename;
  final Future<void> Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Presets',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(count),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chips employees can tap',
          style: TextStyles.caption,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 720;
            final addCard = Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: const Color(0x14000000),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'New preset label',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: primary.withValues(alpha: 0.45),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => onAdd?.call(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onAdd,
                      child: const Text('Add preset'),
                    ),
                  ],
                ),
              ),
            );

            final chips = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (presets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No presets yet',
                      style: TextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in presets)
                        _PresetChip(
                          label: p.label,
                          onEdit:
                              onRename == null ? null : () => onRename!(p),
                          onDelete:
                              onDelete == null ? null : () => onDelete!(p.id),
                        ),
                    ],
                  ),
                if (showSeeAll) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onSeeAll,
                      child: const Text('See all presets'),
                    ),
                  ),
                ],
              ],
            );

            if (!sideBySide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  addCard,
                  const SizedBox(height: 14),
                  chips,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 260, child: addCard),
                const SizedBox(width: 16),
                Expanded(child: chips),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    this.onEdit,
    this.onDelete,
  });

  final String label;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
