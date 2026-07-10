import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/store.dart';
import '../theme.dart';

/// AppBar action that opens a “Scan for review” QR when the company has a URL.
class GoogleReviewQrButton extends StatelessWidget {
  const GoogleReviewQrButton({super.key});

  static void showDialogForUrl(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan for review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Customers can scan this code to leave a Google review.',
              style: TextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
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
