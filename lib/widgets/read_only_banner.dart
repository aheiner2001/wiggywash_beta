import 'package:flutter/material.dart';

import '../services/store.dart';
import '../theme.dart';

/// Banner when the active location is read-only (billing / seats).
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        if (Store.instance.canWriteAtActiveLocation) {
          return const SizedBox.shrink();
        }
        // No active location yet — don't show.
        if (Store.instance.activeLocation == null) {
          return const SizedBox.shrink();
        }
        return Material(
          color: AppColors.warning.withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Store.instance.readOnlyMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
