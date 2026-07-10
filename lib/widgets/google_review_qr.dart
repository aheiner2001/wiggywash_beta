import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/store.dart';
import '../theme.dart';

/// AppBar action that opens a compact “Scan for review” QR when the company has a URL.
class GoogleReviewQrButton extends StatelessWidget {
  const GoogleReviewQrButton({super.key});

  static void showDialogForUrl(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final phone = MediaQuery.sizeOf(ctx).width < 600;
        final qrSize = phone ? 148.0 : 168.0;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan for review',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Customers scan to leave a Google review.',
                  style: TextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E7EF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: qrSize,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final url =
            Store.instance.activeCompany?.googleReviewUrl?.trim() ?? '';
        if (url.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Google review QR',
          onPressed: () => showDialogForUrl(context, url),
          icon: const Icon(Icons.qr_code_2_rounded),
        );
      },
    );
  }
}
