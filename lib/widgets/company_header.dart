import 'package:flutter/material.dart';
import '../models/company.dart';
import '../theme.dart';
import 'brand_header.dart';

/// Company name + logo (or initials) for employee login and pending screens.
class CompanyHeader extends StatelessWidget {
  const CompanyHeader({super.key, this.company, this.height = 88});
  final Company? company;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (company == null) return BrandHeader(height: height);
    final primary = Theme.of(context).colorScheme.primary;
    final initials = company!.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final logo = company!.logoUrl?.trim();
    return Column(
      children: [
        if (logo != null && logo.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              logo,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) => _InitialsAvatar(
                initials: initials,
                radius: height / 2,
                primary: primary,
              ),
            ),
          )
        else
          _InitialsAvatar(
            initials: initials,
            radius: height / 2,
            primary: primary,
          ),
        const SizedBox(height: 12),
        Text(
          company!.name,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text('Sales Scorecard', style: TextStyles.caption),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.radius,
    required this.primary,
  });

  final String initials;
  final double radius;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.64,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
      ),
    );
  }
}
