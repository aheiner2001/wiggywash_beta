import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/scorecard_config.dart';
import '../theme.dart';
import '../utils/sheet_column.dart';
import '../utils/sheet_tools_prefs.dart';

class SheetToolsBar extends StatelessWidget {
  const SheetToolsBar({
    super.key,
    required this.prefs,
    required this.onPrefsChanged,
    required this.employeeNames,
    required this.selectedEmployees,
    required this.onSelectedEmployeesChanged,
    required this.showEmployeeFilter,
    required this.activeFilterCount,
  });

  final SheetToolsPrefs prefs;
  final ValueChanged<SheetToolsPrefs> onPrefsChanged;
  final List<String> employeeNames;
  final Set<String>? selectedEmployees;
  final ValueChanged<Set<String>?> onSelectedEmployeesChanged;
  final bool showEmployeeFilter;
  final int activeFilterCount;

  String _columnLabel(String id) {
    if (id == SheetColumnId.talked) return 'Total Talked';
    if (id == SheetColumnId.vip) return 'Total VIP';
    if (id == SheetColumnId.aboveEco) return 'Above Eco';
    if (id == SheetColumnId.ba) return 'BA %';
    if (id == SheetColumnId.score) return 'Score';
    if (id == SheetColumnId.revenue) return 'Revenue';
    if (id.startsWith('li:')) {
      final itemId = id.substring(3);
      for (final i in kLineItems) {
        if (i.id == itemId) return i.label;
      }
      return itemId;
    }
    return id;
  }

  String _sortLabel(SheetSortKey key) => switch (key) {
        SheetSortKey.nameOrDate => 'Name / Date',
        SheetSortKey.revenue => 'Revenue',
        SheetSortKey.ba => 'BA %',
        SheetSortKey.score => 'Score',
        SheetSortKey.talked => 'Total Talked',
      };

  Future<void> _openColumns(BuildContext context) async {
    final hidden = Set<String>.from(prefs.hiddenColumnIds);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Visible columns', style: TextStyles.subheading),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: true,
                      onChanged: null,
                      title: const Text('Name / Date'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final id in SheetColumnId.allToggleableIds())
                            CheckboxListTile(
                              value: !hidden.contains(id),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(_columnLabel(id)),
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    hidden.remove(id);
                                  } else {
                                    hidden.add(id);
                                  }
                                });
                                onPrefsChanged(
                                  prefs.copyWith(hiddenColumnIds: {...hidden}),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setLocal(() => hidden.clear());
                            onPrefsChanged(
                              prefs.copyWith(hiddenColumnIds: {}),
                            );
                          },
                          child: const Text('Show all'),
                        ),
                        TextButton(
                          onPressed: () {
                            final all = SheetColumnId.allToggleableIds().toSet();
                            setLocal(() {
                              hidden
                                ..clear()
                                ..addAll(all);
                            });
                            onPrefsChanged(
                              prefs.copyWith(hiddenColumnIds: {...all}),
                            );
                          },
                          child: const Text('Hide all'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openFilter(BuildContext context) async {
    final baCtrl = TextEditingController(
      text: prefs.minBa?.toStringAsFixed(0) ?? '',
    );
    final revCtrl = TextEditingController(
      text: prefs.minRevenue?.toStringAsFixed(0) ?? '',
    );
    var selected = Set<String>.from(selectedEmployees ?? {});

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Filter', style: TextStyles.subheading),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Min BA %',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: revCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Min revenue',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    if (showEmployeeFilter) ...[
                      const SizedBox(height: 12),
                      const Text('Employees', style: TextStyles.caption),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final name in employeeNames)
                              CheckboxListTile(
                                dense: true,
                                value: selected.isEmpty ||
                                    selected.contains(name),
                                title: Text(name),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (v) {
                                  setLocal(() {
                                    if (selected.isEmpty) {
                                      selected = employeeNames.toSet();
                                    }
                                    if (v == true) {
                                      selected.add(name);
                                    } else {
                                      selected.remove(name);
                                    }
                                    if (selected.length ==
                                        employeeNames.length) {
                                      selected = {};
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            onPrefsChanged(prefs.copyWith(
                              clearMinBa: true,
                              clearMinRevenue: true,
                            ));
                            onSelectedEmployeesChanged(null);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            final ba = double.tryParse(baCtrl.text.trim());
                            final rev = double.tryParse(revCtrl.text.trim());
                            onPrefsChanged(prefs.copyWith(
                              minBa: ba,
                              clearMinBa: ba == null,
                              minRevenue: rev,
                              clearMinRevenue: rev == null,
                            ));
                            onSelectedEmployeesChanged(
                              selected.isEmpty ? null : selected,
                            );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    baCtrl.dispose();
    revCtrl.dispose();
  }

  Widget _outlineChip({
    required BuildContext context,
    required String label,
    VoidCallback? onTap,
    bool active = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? primary : AppColors.navy,
        ),
      ),
    );
    return Material(
      color: active ? primary.withValues(alpha: 0.12) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: active ? primary : const Color(0xFFE2E7EF),
        ),
      ),
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
    );
  }

  List<Widget> _toolButtons(BuildContext context) {
    final sortLabel =
        'Sort: ${_sortLabel(prefs.sortKey)} ${prefs.sortAsc ? '↑' : '↓'}';
    final filterLabel = activeFilterCount > 0
        ? 'Filter · $activeFilterCount active'
        : 'Filter';
    final densityLabel = switch (prefs.density) {
      SheetDensity.comfortable => 'Density: Comfortable',
      SheetDensity.compact => 'Density: Compact',
      SheetDensity.dense => 'Density: Dense',
    };

    return [
      _outlineChip(
        context: context,
        label: 'Columns',
        onTap: () => _openColumns(context),
        active: prefs.hiddenColumnIds.isNotEmpty,
      ),
      PopupMenuButton<String>(
        tooltip: 'Sort',
        onSelected: (v) {
          if (v == 'asc') {
            onPrefsChanged(prefs.copyWith(sortAsc: true));
            return;
          }
          if (v == 'desc') {
            onPrefsChanged(prefs.copyWith(sortAsc: false));
            return;
          }
          for (final k in SheetSortKey.values) {
            if (k.name == v) {
              onPrefsChanged(prefs.copyWith(sortKey: k));
              return;
            }
          }
        },
        itemBuilder: (_) => [
          for (final k in SheetSortKey.values)
            CheckedPopupMenuItem(
              value: k.name,
              checked: prefs.sortKey == k,
              child: Text(_sortLabel(k)),
            ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'asc',
            checked: prefs.sortAsc,
            child: const Text('Ascending'),
          ),
          CheckedPopupMenuItem(
            value: 'desc',
            checked: !prefs.sortAsc,
            child: const Text('Descending'),
          ),
        ],
        child: _outlineChip(
          context: context,
          label: sortLabel,
          active: prefs.sortKey != SheetSortKey.nameOrDate || !prefs.sortAsc,
        ),
      ),
      _outlineChip(
        context: context,
        label: filterLabel,
        onTap: () => _openFilter(context),
        active: activeFilterCount > 0,
      ),
      PopupMenuButton<SheetDensity>(
        tooltip: 'Density',
        onSelected: (d) => onPrefsChanged(prefs.copyWith(density: d)),
        itemBuilder: (_) => [
          for (final d in SheetDensity.values)
            CheckedPopupMenuItem(
              value: d,
              checked: prefs.density == d,
              child: Text(switch (d) {
                SheetDensity.comfortable => 'Comfortable',
                SheetDensity.compact => 'Compact',
                SheetDensity.dense => 'Dense',
              }),
            ),
        ],
        child: _outlineChip(
          context: context,
          label: densityLabel,
          active: prefs.density != SheetDensity.comfortable,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    if (narrow) {
      return Align(
        alignment: Alignment.centerLeft,
        child: PopupMenuButton<String>(
          tooltip: 'Sheet tools',
          onSelected: (v) {
            switch (v) {
              case 'columns':
                _openColumns(context);
              case 'filter':
                _openFilter(context);
              case 'sort_rev':
                onPrefsChanged(prefs.copyWith(
                  sortKey: SheetSortKey.revenue,
                  sortAsc: false,
                ));
              case 'density_dense':
                onPrefsChanged(
                    prefs.copyWith(density: SheetDensity.dense));
              case 'density_comfy':
                onPrefsChanged(
                    prefs.copyWith(density: SheetDensity.comfortable));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'columns', child: Text('Columns…')),
            PopupMenuItem(value: 'filter', child: Text('Filter…')),
            PopupMenuItem(
                value: 'sort_rev', child: Text('Sort by revenue ↓')),
            PopupMenuItem(
                value: 'density_dense', child: Text('Density: Dense')),
            PopupMenuItem(
                value: 'density_comfy', child: Text('Density: Comfortable')),
          ],
          child: _outlineChip(
            context: context,
            label: activeFilterCount > 0 || prefs.hiddenColumnIds.isNotEmpty
                ? 'Sheet tools · active'
                : 'Sheet tools',
            active: activeFilterCount > 0 || prefs.hiddenColumnIds.isNotEmpty,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _toolButtons(context),
    );
  }
}
