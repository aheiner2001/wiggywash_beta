import 'package:flutter/material.dart';
import '../models/company.dart';
import '../theme.dart';
import 'brand_header.dart';

class CompanyHeader extends StatelessWidget {
  const CompanyHeader({super.key, this.company});
  final Company? company;

  @override
  Widget build(BuildContext context) {
    if (company == null) return const BrandHeader();
    final initials = company!.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Column(
      children: [
        if (company!.logoUrl != null)
          Image.network(company!.logoUrl!, height: 88)
        else
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.blueSoft,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
        const SizedBox(height: 12),
        Text(
          company!.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text('Sales Scorecard', style: TextStyles.caption),
      ],
    );
  }
}
