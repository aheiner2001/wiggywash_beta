import 'package:flutter/material.dart';
import '../theme.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.step, required this.total});
  final int step; // 1-based
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i + 1 == step;
        final done = i + 1 < step;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? AppColors.navy : AppColors.hairline,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
