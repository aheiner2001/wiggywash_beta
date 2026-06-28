import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';
import 'line_items_screen.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// Manager screen to edit the price of every line item. Changes sync live to
/// every device and update all revenue totals.
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  Future<void> _edit(BuildContext context, LineItem item) async {
    final current = PriceBook.priceFor(item.id);
    var charged = current != null;
    final controller = TextEditingController(
      text: current != null ? _trim(current) : '',
    );

    final result = await showDialog<_PriceResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Charged item'),
                subtitle: const Text(
                  'Off = counted only, no dollar value',
                ),
                value: charged,
                onChanged: (v) => setDialog(() => charged = v),
              ),
              if (charged) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '\$ ',
                    hintText: 'Enter price',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!charged) {
                  Navigator.pop(ctx, const _PriceResult(null));
                  return;
                }
                final value =
                    double.tryParse(controller.text.trim().replaceAll(',', ''));
                if (value == null || value < 0) {
                  Navigator.pop(ctx, const _PriceResult.invalid());
                  return;
                }
                Navigator.pop(ctx, _PriceResult(value));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (result == null) return;
    if (!context.mounted) return;

    if (result.invalid) {
      showStoreMessage(context, 'Enter a valid price', error: true);
      return;
    }

    final err = await Store.instance.setItemPrice(item.id, result.price);
    if (!context.mounted) return;
    showStoreMessage(
      context,
      err ?? 'Updated ${item.label}',
      error: err != null,
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Prices')),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Tap any item to set its price. Turn off “Charged item” to '
                    'track it as a count only. Changes apply to everyone instantly.',
                    style: TextStyles.caption,
                  ),
                  const SizedBox(height: 12),
                  const _SectionVisibilityCard(),
                  const SizedBox(height: 14),
                  AppCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LineItemsScreen(),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Icon(Icons.tune_rounded, color: AppColors.navy),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Add, hide & reorder items',
                            style: TextStyles.subheading,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final section in orderedSections()) ...[
                    SectionPill(section.title),
                    const SizedBox(height: 4),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final item in itemsFor(section))
                            _PriceRow(
                              item: item,
                              onTap: () => _edit(context, item),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Per-location toggles for which scorecard sections are in use. Disabled
/// sections disappear from employees' scorecards (e.g. sites without a shop).
class _SectionVisibilityCard extends StatelessWidget {
  const _SectionVisibilityCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        return AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('Sections in use at this location',
                    style: TextStyles.subheading),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8, top: 2, bottom: 4),
                child: Text(
                  'Turn off any section this site doesn\'t sell — employees '
                  'won\'t see it on their scorecard.',
                  style: TextStyles.caption,
                ),
              ),
              for (final section in WashSection.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(section.title),
                  value: Store.instance.isSectionEnabled(section),
                  onChanged: (v) async {
                    final err =
                        await Store.instance.setSectionEnabled(section, v);
                    if (context.mounted && err != null) {
                      showStoreMessage(context, err, error: true);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, required this.onTap});
  final LineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = PriceBook.priceFor(item.id);
    return ListTile(
      onTap: onTap,
      title: Text(
        item.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: price == null
          ? const Text('Count only', style: TextStyles.caption)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            price != null ? _money.format(price) : '—',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: price != null ? AppColors.navy : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _PriceResult {
  const _PriceResult(this.price) : invalid = false;
  const _PriceResult.invalid()
      : price = null,
        invalid = true;

  final double? price;
  final bool invalid;
}
