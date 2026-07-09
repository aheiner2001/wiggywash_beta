import 'package:flutter/material.dart';

import '../models/company.dart';
import '../theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final CompanyStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CompanyStatus.pending => ('Pending', AppColors.warning),
      CompanyStatus.active => ('Active', AppColors.success),
      CompanyStatus.suspended => ('Suspended', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
