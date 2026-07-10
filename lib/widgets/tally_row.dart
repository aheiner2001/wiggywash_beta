import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// A single scorecard line: label + price, a +/- tally counter, and a blue
/// total box on the right showing the live dollar (or count) total.
class TallyRow extends StatelessWidget {
  const TallyRow({
    super.key,
    required this.item,
    required this.count,
    required this.onChanged,
    this.stepButtonSize = 38,
    this.verticalMargin = 5,
  });

  final LineItem item;
  final int count;
  final ValueChanged<int> onChanged;
  final double stepButtonSize;
  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    final price = priceOf(item);
    final lineTotal = price != null ? count * price : null;

    return Container(
      margin: EdgeInsets.symmetric(vertical: verticalMargin),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (price != null)
                  Text(
                    _money.format(price),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: count > 0,
            size: stepButtonSize,
            onTap: () => onChanged(count > 0 ? count - 1 : 0),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: true,
            size: stepButtonSize,
            onTap: () => onChanged(count + 1),
          ),
          const SizedBox(width: 8),
          _TotalBox(
            text: lineTotal != null ? _money.format(lineTotal) : '$count',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.size = 38,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.navy : AppColors.hairline,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size >= 48 ? 26 : 22,
            color: enabled ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TotalBox extends StatelessWidget {
  const _TotalBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.0)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.navyDark,
          ),
        ),
      ),
    );
  }
}
