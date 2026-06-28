import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';

final _money = NumberFormat.simpleCurrency(decimalDigits: 0);

/// Manager screen to add custom line items, hide built-ins, and reorder both
/// items (within a section) and the sections themselves.
class LineItemsScreen extends StatelessWidget {
  const LineItemsScreen({super.key});

  Future<void> _addItem(BuildContext context, WashSection section) async {
    final labelCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final pointsCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to ${section.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Price (optional)',
                hintText: 'Leave blank for count-only',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Points (OVERALL SCORE)',
                hintText: 'e.g. 10',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (created != true) return;
    final label = labelCtrl.text.trim();
    if (label.isEmpty) return;
    final price = double.tryParse(priceCtrl.text.trim());
    final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
    final err =
        await Store.instance.addCustomLineItem(label, section, price, points: points);
    if (context.mounted && err != null) {
      showStoreMessage(context, err, error: true);
    }
  }

  Future<void> _editPoints(BuildContext context, LineItem item) async {
    final ctrl = TextEditingController(text: '${pointOf(item)}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Points · ${item.label}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Points per sale',
            helperText: 'Used for the OVERALL SCORE column',
          ),
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
    if (ok != true) return;
    final points = int.tryParse(ctrl.text.trim()) ?? 0;
    final err = await Store.instance.setItemPoints(item.id, points);
    if (context.mounted && err != null) {
      showStoreMessage(context, err, error: true);
    }
  }

  void _moveItem(WashSection section, int index, int delta) {
    final ids =
        Store.instance.managedItemsFor(section).map((i) => i.id).toList();
    final target = index + delta;
    if (target < 0 || target >= ids.length) return;
    final id = ids.removeAt(index);
    ids.insert(target, id);
    Store.instance.reorderLineItems(section, ids);
  }

  void _moveSection(int index, int delta) {
    final order = [...SectionBook.order];
    final target = index + delta;
    if (target < 0 || target >= order.length) return;
    final s = order.removeAt(index);
    order.insert(target, s);
    Store.instance.reorderSections(order);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scorecard Items')),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final sections = SectionBook.order;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      'Add your own items, hide ones you don’t use, and drag the '
                      'arrows to reorder. Changes apply to every scorecard at '
                      'this location.',
                      style: TextStyles.caption,
                    ),
                  ),
                  for (var s = 0; s < sections.length; s++)
                    _SectionCard(
                      section: sections[s],
                      isFirst: s == 0,
                      isLast: s == sections.length - 1,
                      onMoveUp: () => _moveSection(s, -1),
                      onMoveDown: () => _moveSection(s, 1),
                      onAdd: () => _addItem(context, sections[s]),
                      onMoveItem: (i, d) => _moveItem(sections[s], i, d),
                      onEditPoints: (item) => _editPoints(context, item),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onAdd,
    required this.onMoveItem,
    required this.onEditPoints,
  });

  final WashSection section;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onAdd;
  final void Function(int index, int delta) onMoveItem;
  final void Function(LineItem item) onEditPoints;

  @override
  Widget build(BuildContext context) {
    final items = Store.instance.managedItemsFor(section);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(section.title, style: TextStyles.subheading),
                ),
                IconButton(
                  tooltip: 'Move section up',
                  visualDensity: VisualDensity.compact,
                  onPressed: isFirst ? null : onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  tooltip: 'Move section down',
                  visualDensity: VisualDensity.compact,
                  onPressed: isLast ? null : onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < items.length; i++)
              _ItemRow(
                item: items[i],
                hidden: Store.instance.isItemHidden(items[i].id),
                isFirst: i == 0,
                isLast: i == items.length - 1,
                onUp: () => onMoveItem(i, -1),
                onDown: () => onMoveItem(i, 1),
                onEditPoints: () => onEditPoints(items[i]),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.hidden,
    required this.isFirst,
    required this.isLast,
    required this.onUp,
    required this.onDown,
    required this.onEditPoints,
  });

  final LineItem item;
  final bool hidden;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onEditPoints;

  @override
  Widget build(BuildContext context) {
    final custom = isCustomItem(item.id);
    final price = priceOf(item);
    return Opacity(
      opacity: hidden ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Column(
              children: [
                _MiniArrow(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onTap: isFirst ? null : onUp,
                ),
                _MiniArrow(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: isLast ? null : onDown,
                ),
              ],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (custom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.blueSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Custom',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${price != null ? _money.format(price) : 'Count only'}  •  ${pointOf(item)} pts',
                    style: TextStyles.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit points',
              visualDensity: VisualDensity.compact,
              onPressed: onEditPoints,
              icon: const Icon(Icons.stars_rounded,
                  size: 20, color: AppColors.navy),
            ),
            IconButton(
              tooltip: hidden ? 'Show on scorecard' : 'Hide from scorecard',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  Store.instance.setLineItemHidden(item.id, !hidden),
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: hidden ? AppColors.textMuted : AppColors.navy,
              ),
            ),
            if (custom)
              IconButton(
                tooltip: 'Delete item',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    Store.instance.removeCustomLineItem(item.id),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniArrow extends StatelessWidget {
  const _MiniArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? AppColors.hairline : AppColors.textMuted,
        ),
      ),
    );
  }
}
