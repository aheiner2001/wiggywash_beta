import 'package:flutter/material.dart';

import '../theme.dart';

/// The Wiggy Wash logo lockup used on the onboarding screen.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.height = 112});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Text(
            'WIGGY WASH',
            style: TextStyle(
              fontSize: height * 0.3,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sales Scorecard',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}
